//
//  LFVideoDecode.h
//  LFRtmp
//
//  Created by liuf on 2017/6/9.
//  Copyright © 2017年 liufang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LFVideoPacketData.h"
#import "LFPlayConfig.h"
#import <VideoToolbox/VideoToolbox.h>
@protocol LFVideoDecodeDelegate <NSObject>
/**
 *  返回解码后的数据
 *  @param playConfig
 *  @return instancetype
 */
-(void)onDidVideoDecodeOutput:(CVPixelBufferRef)pixelBuffer;

@end

@interface LFVideoDecode : NSObject
/**
 * delegate
 */
@property (weak,nonatomic) id<LFVideoDecodeDelegate> delegate;
/**
 *  初始化
 *  @param playConfig
 *  @return instancetype
 */
-(instancetype)init:(LFPlayConfig *)playConfig;
/**
 *  解码
 *  @param videoPacket 音频数据
 */
-(void)decode:(LFVideoPacketData *)videoPacket;
/**
 *  释放解码器
 */
-(void)clearDecoder;
@end
