//
//  UILoadingView.m
//  CordovaLib
//
//  Created by Emil Atanasov on 16.12.21.
//

#import <Foundation/Foundation.h>
#import "UILoadingView.h"

NSString * kAnimationKey = @"rotation";

@implementation UILoadingView

-(void) startRotating:(float) duration {
        if([self.spinner.layer animationForKey:kAnimationKey] == nil) {
            CABasicAnimation * animate = [[CABasicAnimation alloc] init];
            animate.keyPath = @"transform.rotation";
            animate.duration = duration;
            animate.repeatCount = CGFLOAT_MAX;
            animate.fromValue = [NSNumber numberWithFloat: 0.0f];
            animate.toValue = [NSNumber numberWithFloat: (M_PI * 25.0f)];
            [self.spinner.layer addAnimation:animate forKey:kAnimationKey];
        }
    }

-(void) stopRotating {
        if([self.spinner.layer animationForKey:kAnimationKey] != nil) {
            [self.spinner.layer removeAnimationForKey:kAnimationKey];
        }
    }

@end
