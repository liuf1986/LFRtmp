//
//  LFVideoEncodeInfo.h
//  myrtmp
//
//  Created by liuf on 16/8/12.
// 
//

#import <Foundation/Foundation.h>

@interface LFVideoEncodeInfo : NSObject
/**
 *  是否关键帧
 */
@property (assign,nonatomic) BOOL isKeyFrame;
/**
 *  视频的sps信息
 */
@property (strong,nonatomic) NSData *sps;
/**
 *  视频的pps信息
 */
@property (strong,nonatomic) NSData *pps;
/**
 *  视频数据
 */
@property (strong,nonatomic) NSData *data;
/**
 *  时间戳
 */
@property (assign,nonatomic) uint32_t timeStamp;
@end
