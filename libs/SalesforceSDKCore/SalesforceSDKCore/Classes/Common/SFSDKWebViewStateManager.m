/*
 Copyright (c) 2017-present, salesforce.com, inc. All rights reserved.

 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#import <WebKit/WebKit.h>
#import "SFSDKWebViewStateManager.h"
#import "SFUserAccountManager.h"
#import "NSString+SFAdditions.h"
static NSString *const SID_COOKIE = @"sid";
static NSString *const TRUE_STRING = @"TRUE";
static NSString *const ERR_NO_DOMAIN_NAMES = @"No domain names given for deleting cookies.";
static NSString *const ERR_NO_COOKIE_NAMES = @"No cookie names given to delete.";

@implementation SFSDKWebViewStateManager

static WKProcessPool *_processPool = nil;

+ (void)removeSession {
    //reset Web View related state if any
    [self removeUIWebViewCookies:@[SID_COOKIE] fromDomains:self.domains];
    self.sharedProcessPool = nil;
}

+ (WKProcessPool *)sharedProcessPool {
    if (!_processPool) {
        _processPool = [[WKProcessPool alloc] init];
    }
    return _processPool;
}

+ (void)setSharedProcessPool:(WKProcessPool *)sharedProcessPool {
    if (sharedProcessPool != _processPool) {
        _processPool = sharedProcessPool;
    }
}

#pragma mark Private helper methods
+ (void)removeUIWebViewCookies:(NSArray *)cookieNames fromDomains:(NSArray *)domainNames {
    NSAssert(cookieNames != nil && [cookieNames count] > 0, ERR_NO_COOKIE_NAMES);
    NSAssert(domainNames != nil && [domainNames count] > 0, ERR_NO_DOMAIN_NAMES);
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *fullCookieList = [NSArray arrayWithArray:[cookieStorage cookies]];
    for (NSHTTPCookie *cookie in fullCookieList) {
        for (NSString *cookieToRemoveName in cookieNames) {
            if ([[cookie.name lowercaseString] isEqualToString:[cookieToRemoveName lowercaseString]]) {
                for (NSString *domainToRemoveName in domainNames) {
                    if ([[cookie.domain lowercaseString] hasSuffix:[domainToRemoveName lowercaseString]]) {
                        [cookieStorage deleteCookie:cookie];
                    }
                }
            }
        }
    }
}

+ (void)removeWKWebViewCookies:(NSArray *)domainNames withCompletion:(nullable void(^)(void))completionBlock {
    NSAssert(domainNames != nil && [domainNames count] > 0, ERR_NO_DOMAIN_NAMES);
    WKWebsiteDataStore *dateStore = [WKWebsiteDataStore defaultDataStore];
    NSSet *websiteDataTypes = [NSSet setWithArray:@[ WKWebsiteDataTypeCookies]];
    [dateStore fetchDataRecordsOfTypes:websiteDataTypes
                     completionHandler:^(NSArray<WKWebsiteDataRecord *> *records) {
                         NSMutableArray<WKWebsiteDataRecord *> *deletedRecords = [NSMutableArray new];
                         for ( WKWebsiteDataRecord * record in records) {
                             for(NSString *domainName in domainNames) {
                                 if ([record.displayName containsString:domainName]) {
                                     [deletedRecords addObject:record];
                                 }
                             }
                         }
                         if (deletedRecords.count > 0)
                             [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes
                                                                       forDataRecords:deletedRecords
                                                                    completionHandler:^{
                                                                        if (completionBlock)
                                                                            completionBlock();
                                                                    }];
                     }];
}

+ (NSArray<NSString *> *) domains {
    return @[@".salesforce.com", @".force.com", @".cloudforce.com"];
}

+ (void)resetSessionCookie:(nullable void (^)(BOOL success))completion
{
    NSString *baseUrl = [[SFUserAccountManager sharedInstance].currentUser.credentials.apiUrl absoluteString];
    NSString *accessToken = [SFUserAccountManager sharedInstance].currentUser.credentials.accessToken;
    NSString *retUrl = [[NSString stringWithFormat:@"%@%@", baseUrl, @"/apex/FMPApp"] stringByURLEncoding];
    NSString *cookieRefreshUrl = [NSString stringWithFormat:@"%@/secur/frontdoor.jsp?sid=%@&retURL=%@", baseUrl, accessToken, retUrl];
    
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *urlSession = [NSURLSession sessionWithConfiguration:sessionConfig delegate:(id<NSURLSessionDelegate>)[self class] delegateQueue:nil];
    
    NSURLSessionDataTask *getDataTask = [urlSession dataTaskWithURL:[NSURL URLWithString:cookieRefreshUrl] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (error) {
            NSLog(@"Fourth:resetSessionCookie error: %@", [error localizedDescription]);
            
            if (completion) {
                completion(false);
            }
            
            return;
        }
        
        if (!response) {
            if (completion) {
                completion(false);
            }
            
            return;
        }
        
        NSHTTPURLResponse *resp = (NSHTTPURLResponse*)response;
        NSDictionary *headers = [resp allHeaderFields];
        NSURL *url = [resp URL];
        
        if (!headers || !url) {
            if (completion) {
                completion(false);
            }
            
            return;
        }
        
        if (resp.statusCode != 200) {
            if (completion) {
                completion(false);
            }
            
            return;
        }
        
        if (@available(iOS 11.0, *)) {
            __block BOOL hasOldCookies = NO;
            NSMutableArray<NSHTTPCookie *> * oldCookeiesToDelete = [NSMutableArray new];
            dispatch_group_t findOldCookiesGroup = dispatch_group_create();
            for (NSHTTPCookie *cookie in [NSHTTPCookie cookiesWithResponseHeaderFields:headers forURL:url]) {
                dispatch_group_async(findOldCookiesGroup, dispatch_get_main_queue(), ^{
                    WKHTTPCookieStore *webviewCookiesStore = [[WKWebsiteDataStore defaultDataStore] httpCookieStore];
                    
                    dispatch_group_enter(findOldCookiesGroup);
                    [webviewCookiesStore getAllCookies:^(NSArray<NSHTTPCookie *> *allCookies) {
                        for (NSHTTPCookie *oldCookie in allCookies) {
                            if ([cookie.name isEqualToString:oldCookie.name]) {
                                 [oldCookeiesToDelete addObject:oldCookie];
                                 hasOldCookies = YES;
                            }
                        }
                        dispatch_group_leave(findOldCookiesGroup);
                    }];
                });
            }
            dispatch_group_wait(findOldCookiesGroup, DISPATCH_TIME_FOREVER);
            
            if (hasOldCookies == YES) {
                dispatch_group_t deleteOldCookiesGroup = dispatch_group_create();
                dispatch_group_async(deleteOldCookiesGroup, dispatch_get_main_queue(), ^{
                    for (NSHTTPCookie *oldCookie in oldCookeiesToDelete) {
                        WKHTTPCookieStore *webviewCookiesStore = [[WKWebsiteDataStore defaultDataStore] httpCookieStore];
                        
                        dispatch_group_enter(deleteOldCookiesGroup);
                        [webviewCookiesStore deleteCookie:oldCookie completionHandler:^{
                            dispatch_group_leave(deleteOldCookiesGroup);
                        }];
                    }
                });
                dispatch_group_wait(deleteOldCookiesGroup, DISPATCH_TIME_FOREVER);
            }
            
            dispatch_group_t setCookiesGroup = dispatch_group_create();
            for (NSHTTPCookie *cookie in [NSHTTPCookie cookiesWithResponseHeaderFields:headers forURL:url]) {
                dispatch_group_async(setCookiesGroup, dispatch_get_main_queue(), ^{
                    WKHTTPCookieStore *webviewCookiesStore = [[WKWebsiteDataStore defaultDataStore] httpCookieStore];
                    
                    dispatch_group_enter(setCookiesGroup);
                    [webviewCookiesStore setCookie:cookie completionHandler:^{
                        dispatch_group_leave(setCookiesGroup);
                    }];
                });
            }
            dispatch_group_wait(setCookiesGroup, DISPATCH_TIME_FOREVER);
        }
        
        if (completion) {
            completion(true);
        }
    }];
    
    [getDataTask resume];
}

+ (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                     willPerformHTTPRedirection:(NSHTTPURLResponse *)response
                                     newRequest:(NSURLRequest *)request
                              completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler
{
    completionHandler(nil); // Don't follow redirects
}

@end
