//
//  LFVideoPacketData.h
//  LFRtmp
//
//  Created by liuf on 2017/6/8.
//  Copyright © 2017年 liufang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LFPlayConfig.h"
@interface LFVideoPacketData : NSObject
/**
 *  是否为关键帧
 */
@property (assign,nonatomic) BOOL isKeyFrame;
/**
 *  视频编解码器类型
 */
@property (assign,nonatomic) LFPlayVideoCodecIDType codecID;
/**
 *  h264数据
 */
@property (strong,nonatomic) NSMutableArray *datas;
@end
