//
//  LFAudioDataParser.h
//  LFRtmp
//
//  Created by liuf on 2017/5/17.
//  Copyright © 2017年 liufang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LFPlayConfig.h"
@interface LFAudioDataParser : NSObject
/**
 *  解析音频同步头数据，并将结果给到LFPlayConfig
 *
 *  @param data 同步头数据
 *  @param config 存放解析结果
 *  @return 是否解析成功
 */
+(BOOL)parseAudioSequenceHeader:(NSData *)data withConfig:(LFPlayConfig *)config;
/**
 *  解析音频数据
 *
 *  @param data 音频数据
 *  @return 清除了FLV tag 后的数据
 */
+(NSData *)parseAudioData:(NSData *)data;
/**
 *  解析视频同步头数据，并将结果给到LFPlayConfig
 *
 *  @param data 同步头数据
 *  @param config 存放解析结果
 *  @return 是否解析成功
 */
@end
