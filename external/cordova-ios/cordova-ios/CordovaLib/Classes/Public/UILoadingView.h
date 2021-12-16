//
//  UILoadingView.h
//  CordovaLib
//
//  Created by Emil Atanasov on 16.12.21.
//
#import <UIKit/UIKit.h>

#ifndef UILoadingView_h
#define UILoadingView_h
@interface UILoadingView : UIView

@property (weak, nonatomic) IBOutlet UIImageView *spinner;
@property (weak, nonatomic) IBOutlet UILabel *text;
@property (weak, nonatomic) IBOutlet UILabel *subtitle;


-(void) startRotating:(float) duration;
-(void) stopRotating;

@end

#endif /* UILoadingView_h */
