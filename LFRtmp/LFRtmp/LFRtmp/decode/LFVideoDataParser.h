//
//  LFVideoDataParser.h
//  LFRtmp
//
//  Created by liuf on 2017/5/17.
//  Copyright © 2017年 liufang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LFPlayConfig.h"
#import "LFVideoPacketData.h"
@interface LFVideoDataParser : NSObject

/**
 *  解析视频同步头数据，并将结果给到LFPlayConfig
 *
 *  @param data 同步头数据
 *  @param config 存放解析结果
 *  @return 是否解析成功
 */
+(BOOL)parseVideoSequenceHeader:(NSData *)data withConfig:(LFPlayConfig *)config;
/**
 *  解析视频数据包
 *
 *  @param data 视频数据包
 *  @return 清除了FLV tag 后的数据
 */
+(LFVideoPacketData *)parseVideoData:(NSData *)data;
@end
