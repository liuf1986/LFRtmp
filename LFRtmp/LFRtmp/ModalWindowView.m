//
//  ModalWindowView.m
//  frame
//
//  Created by chenang on 14-9-13.
//  Copyright (c) 2014年 chen. All rights reserved.
//

#import "ModalWindowView.h"

@implementation ModalWindowView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}
-(void)show:(BOOL)isAnimation
{
    [self setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:.0]];
    [UIView animateWithDuration:0.25 animations:^{
        [self setBackgroundColor:[[UIColor blackColor] colorWithAlphaComponent:.3]];
    }];
    UIWindow *window = [[[UIApplication sharedApplication]delegate]window];
    [window addSubview:self];
    if(isAnimation)
    {
        [self exChangeIn:self dur:.3];
    }
}

-(void)hide:(BOOL)isAnimation
{
    if(isAnimation)
    {
        [self exChangeOut:self dur:.3];
    }
    [self removeFromSuperview];
}

- (void)exChangeOut:(UIView *)changeOutView dur:(CFTimeInterval)dur
{
    
    CAKeyframeAnimation * animation;
    animation = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
    animation.duration = dur;
    animation.delegate = self;
    animation.removedOnCompletion = NO;
    animation.fillMode = kCAFillModeForwards;
    NSMutableArray *values = [NSMutableArray array];
    [values addObject:[NSValue valueWithCATransform3D:CATransform3DMakeScale(0.9, 0.9, 0.9)]];
    [values addObject:[NSValue valueWithCATransform3D:CATransform3DMakeScale(0.1, 0.1, 0.1)]];
    animation.values = values;
    animation.timingFunction = [CAMediaTimingFunction functionWithName: @"easeInEaseOut"];
    [changeOutView.layer addAnimation:animation forKey:nil];
}
- (void)exChangeIn:(UIView *)changeOutView dur:(CFTimeInterval)dur
{
    CAKeyframeAnimation * animation;
    animation = [CAKeyframeAnimation animationWithKeyPath:@"transform"];
    animation.duration = dur;
    animation.removedOnCompletion = NO;
    animation.fillMode = kCAFillModeForwards;
    NSMutableArray *values = [NSMutableArray array];
    [values addObject:[NSValue valueWithCATransform3D:CATransform3DMakeScale(0.1, 0.1, 1.0)]];
    [values addObject:[NSValue valueWithCATransform3D:CATransform3DMakeScale(1.0, 1.0, 1.0)]];
    animation.values = values;
    animation.timingFunction = [CAMediaTimingFunction functionWithName: @"easeInEaseOut"];
    [changeOutView.layer addAnimation:animation forKey:nil];
}

@end
