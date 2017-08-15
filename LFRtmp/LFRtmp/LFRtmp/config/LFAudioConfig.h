//
//  LFAudioConfig.h
//  myrtmp
//
//  Created by liuf on 16/8/4.
//
//
/**
 音频配置信息
 */
#import <Foundation/Foundation.h>
//音频码率
typedef enum : int {
    //32k音频码率
    LFAudioConfigBitRate_32k=32000,
    //64k音频码率
    LFAudioConfigBitRate_64k=64000,
    //96k音频码率
    LFAudioConfigBitRate_96k=96000,
    //128k音频码率
    LFAudioConfigBitRate_128k=128000
} LFAudioConfigBitRate;

//音频采样率
typedef enum : int {
    //48k音频码率
    LFAudioConfigSampleRate_48k=48000,
    //44k音频码率
    LFAudioConfigSampleRate_44k=44100
} LFAudioConfigSampleRate;
//声道
typedef enum : char {
    //单声道
    LFAudioConfigChannelSingle=1,
    //立体声
    LFAudioConfigChannelStereo=2
} LFAudioConfigChannel;

//音频质量
typedef enum : char {
    //码率为32k，采样率44k
    LFAudioConfigQuality_Low=1,
    //码率为64k，采样率44k
    LFAudioConfigQuality_Default=2,
    //码率为96k，采样率44k
    LFAudioConfigQuality_Hight=3,
    //码率为128k，采样率44k
    LFAudioConfigQuality_Highest=4
} LFAudioConfigQuality;

@interface LFAudioConfig : NSObject
/**
 *  通过默认配置实例化
 *
 *  @return self
 */
+(instancetype)defaultConfig;

/**
 *  通过LFAudioConfigQuality初始化
 *
 *  @param quality 音频质量
 *
 *  @return self
 */
-(instancetype)init:(LFAudioConfigQuality)quality;
/**
 *  码率
 */
@property (assign,nonatomic,readonly) LFAudioConfigBitRate bitRate;
/**
 *  采样率
 */
@property (assign,nonatomic,readonly) LFAudioConfigSampleRate sampleRate;
/**
 *  声道数
 */
@property (assign,nonatomic,readonly) LFAudioConfigChannel channel;
/**
 *  位元深度，默认16
 */
@property (assign,nonatomic,readonly) int bitDepth;
@end
