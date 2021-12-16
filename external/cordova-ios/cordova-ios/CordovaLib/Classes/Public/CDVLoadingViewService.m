//
//  CDVLoadingViewService.m
//  CordovaLib
//
//  Created by Spas Bilyarski on 31.01.19.
//

#import "CDVLoadingViewService.h"

@implementation CDVLoadingViewService

+ (CDVLoadingViewService *)sharedInstance
{
    static CDVLoadingViewService *sharedInstance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        sharedInstance = [[CDVLoadingViewService alloc] init];
    });
    
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        UILoadingView *loadingView = (UILoadingView *) [[[NSBundle mainBundle] loadNibNamed:@"LoadingView" owner:self options:nil] firstObject];
        loadingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        self.view = loadingView;
    }
    return self;
}

@end
