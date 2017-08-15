//
//  LFAudioConfig.m
//  myrtmp
//
//  Created by liuf on 16/8/4.
//
//

#import "LFAudioConfig.h"
#import "DevicePlatform.h"
@implementation LFAudioConfig
/**
 *  通过默认配置实例化
 *
 *  @return self
 */
+(instancetype)defaultConfig{
    return [[LFAudioConfig alloc] init:LFAudioConfigQuality_Default];
}

/**
 *  通过LFAudioConfigQuality初始化
 *
 *  @param quality 音频质量
 *
 *  @return self
 */
-(instancetype)init:(LFAudioConfigQuality)quality;{
    self=[super init];
    if(self){
        [self splitConfig:quality];
    }
    return self;
}
/**
 *  拆分配置
 *
 *  @param quality 配置
 */
-(void)splitConfig:(LFAudioConfigQuality)quality{
    switch (quality) {
        case LFAudioConfigQuality_Low:
        {
            _bitRate=LFAudioConfigBitRate_32k;
        }
            break;
        case LFAudioConfigQuality_Default:
        {
            _bitRate=LFAudioConfigBitRate_64k;
        }
            break;
        case LFAudioConfigQuality_Hight:
        {
            _bitRate=LFAudioConfigBitRate_96k;
        }
            break;
        case LFAudioConfigQuality_Highest:
        {
            _bitRate=LFAudioConfigBitRate_128k;
        }
            break;
        default:
            break;
    }
    if([DevicePlatform isIphone6sHLevel]){
        _sampleRate=LFAudioConfigSampleRate_48k;
    }else{
        _sampleRate=LFAudioConfigSampleRate_44k;
    }
    _bitDepth=16;//16位
    _channel=LFAudioConfigChannelStereo;
}

@end
