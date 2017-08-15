//
//  DevicePlatform.h
//  LFRtmp
//
//  Created by liuf on 2017/5/5.
//  Copyright © 2017年 liuf. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DevicePlatform : NSObject
/**
 *  当前设备平台号
 *
 *  @return 当前设备平台号
 */
+(NSString *)currentPlatform;
/**
 *  是否iphone6s以上设备
 *
 *  @return 是否iphone6s以上设备
 */
+(BOOL)isIphone6sHLevel;
@end
