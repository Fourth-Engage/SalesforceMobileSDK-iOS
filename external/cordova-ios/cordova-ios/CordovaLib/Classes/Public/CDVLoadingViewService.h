//
//  CDVLoadingViewService.h
//  CordovaLib
//
//  Created by Spas Bilyarski on 31.01.19.
//

#import <UIKit/UIKit.h>
#import "UILoadingView.h"

NS_ASSUME_NONNULL_BEGIN

@interface CDVLoadingViewService : NSObject

+ (CDVLoadingViewService *)sharedInstance;

@property (strong, nonatomic) UILoadingView *view;

@end

NS_ASSUME_NONNULL_END
