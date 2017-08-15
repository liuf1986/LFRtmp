//
//  DevicePlatform.m
//  LFRtmp
//
//  Created by liuf on 2017/5/5.
//  Copyright © 2017年 liuf. All rights reserved.
//

#import "DevicePlatform.h"
#import <sys/utsname.h>
@implementation DevicePlatform
/**
 *  当前设备平台号
 *
 *  @return 当前设备平台号
 */
+(NSString *)currentPlatform{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *platform = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    return platform;
}
/**
 *  是否iphone6s以上设备
 *
 *  @return 是否iphone6s以上设备
 */
+(BOOL)isIphone6sHLevel{
    NSString *platform=[DevicePlatform currentPlatform];
    if ([platform isEqualToString:@"iPhone1,1"]) return NO;
    
    if ([platform isEqualToString:@"iPhone1,2"]) return NO;
    
    if ([platform isEqualToString:@"iPhone2,1"]) return NO;
    
    if ([platform isEqualToString:@"iPhone3,1"]) return NO;
    
    if ([platform isEqualToString:@"iPhone3,2"]) return NO;
    
    if ([platform isEqualToString:@"iPhone3,3"]) return NO;
    
    if ([platform isEqualToString:@"iPhone4,1"]) return NO;
    
    if ([platform isEqualToString:@"iPhone5,1"]) return NO;
    
    if ([platform isEqualToString:@"iPhone5,2"]) return NO;
    
    if ([platform isEqualToString:@"iPhone5,3"]) return NO;
    
    if ([platform isEqualToString:@"iPhone5,4"]) return NO;
    
    if ([platform isEqualToString:@"iPhone6,1"]) return NO;
    
    if ([platform isEqualToString:@"iPhone6,2"]) return NO;
    
    if ([platform isEqualToString:@"iPhone7,1"]) return NO;
    
    if ([platform isEqualToString:@"iPhone7,2"]) return NO;
    
    if ([platform isEqualToString:@"iPhone8,4"]) return NO;

    return YES;
}
@end
