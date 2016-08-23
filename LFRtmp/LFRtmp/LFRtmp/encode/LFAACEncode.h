//
//  LFAACEncode.h
//  myrtmp
//
//  Created by liuf on 16/8/3.
// 
//
/**
 * AAC编码器，将PCM转换为AAC，采用硬件编码
 */
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LFAudioConfig.h"
@interface LFAACEncode : NSObject

/**
 *  初始化
 *
 *  @param audioConfig 音频配置信息
 *
 *  @return self
 */
-(instancetype)init:(LFAudioConfig *)audioConfig;
/**
 *  AAC编码
 *
 *  @param audioBufferList audioBufferList
 *
 *  @return 返回经过AAC编码后的NSData
 */
-(NSData *)encode:(AudioBufferList)audioBufferList;

@end
