//
//  LFMicDevice.h
//  myrtmp
//
//  Created by liuf on 16/8/3.
// 
//
/**
 *  音频采集
 */
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LFAudioConfig.h"

@protocol LFMicDeviceDelegate <NSObject>
/**
 *  音频采集到的PCM数据输出
 *
 *  @param audioBufferList
 */
-(void)onMicOutputData:(AudioBufferList)audioBufferList;

@end
@interface LFMicDevice : NSObject
@property (weak,nonatomic) id<LFMicDeviceDelegate> delegate;
/**
 *  初始化
 *
 *  @param audioConfig 音频采样配置
 */
-(instancetype)init:(LFAudioConfig *)audioConfig;
/**
 *  停止采集
 */
-(void)stopOutput;
/**
 *  启动采集
 */
-(void)startOuput;

@end
