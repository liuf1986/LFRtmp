//
//  LFPlayConfig.h
//  LFRtmp
//
//  Created by liuf on 2017/5/11.
//  Copyright © 2017年 liufang. All rights reserved.
//
#define kLFPlayConfigADTSLength 7
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioQueue.h>
//音频编码类型
typedef enum : char {
    //Linear PCM, platform endian
    LFPlayAudioFormatPCMPlatformEndian=0,
    //ADPCM
    LFPlayAudioFormatADPCM=1,
    //MP3
    LFPlayAudioFormatMP3=2,
    // Linear PCM, little endian
    LFPlayAudioFormatPCMLittleEndian=3,
    //Nellymoser 16 kHz mono
    LFPlayAudioFormatNellymoser16kHzMono=4,
    //Nellymoser 8 kHz mono
    LFPlayAudioFormatNellymoser8kHzMono=5,
    //Nellymoser
    LFPlayAudioFormatNellymoser=6,
    //G.711 A-law logarithmic PCM
    LFPlayAudioFormatPCMG711AlawLogarithmic=7,
    // G.711 mu-law logarithmic PCM
    LFPlayAudioFormatPCMG711MulawLogarithmic=8,
    //reserved
    LFPlayAudioFormatReserved=9,
    //AAC
    LFPlayAudioFormatAAC=10,
    //Speex
    LFPlayAudioFormatSpeex=11,
    //MP3 8 kHz
    LFPlayAudioFormatMP38kHz=14,
    // Device-specific sound
    LFPlayAudioFormatDeviceSpecificSound=15
    
} LFPlayAudioFormat;

//音频采样率
typedef enum : int {
    //96000
    LFPlayAudioSamplerate96000=0,
    //88200
    LFPlayAudioSamplerate88200=1,
    //64000
    LFPlayAudioSamplerate64000=2,
    //48000
    LFPlayAudioSamplerate48000=3,
    //44100
    LFPlayAudioSamplerate44100=4,
    //32000
    LFPlayAudioSamplerate32000=5,
    //24000
    LFPlayAudioSamplerate24000=6,
    //22050
    LFPlayAudioSamplerate22050=7,
    //16000
    LFPlayAudioSamplerate16000=8,
    //12000
    LFPlayAudioSamplerate12000=9,
    //11025
    LFPlayAudioSamplerate11025=10,
    //8000
    LFPlayAudioSamplerate8000=11
    
} LFPlayAudioSamplerate;

//音频编码类型
typedef enum : char {
    //Linear PCM, platform endian
    LFPlayAACProfileAACMain=1,
    LFPlayAACProfileAACLC=2,
    LFPlayAACProfileAACSSR=3,
} LFPlayAACProfile;

//视频帧类型
typedef enum : char {
    LFPlayVideoFrameKeyFrame=1,//关键帧IDR
    LFPlayVideoFrameInterFrame=2,//I帧
    LFPlayVideoFrameDisposableInterFrame=3,//h263使用
    LFPlayVideoFrameGeneratedKeyFrame=4,//服务端保留使用
    LFPlayVideoFrameVideoInfoOrCommandFrame=5//
} LFPlayVideoFrameType;

//视频编解码器类型
typedef enum : char {
    LFPlayVideoCodecIDJPEG=1,
    LFPlayVideoCodecIDH263=2,
    LFPlayVideoCodecIDScreenVideo=3,
    LFPlayVideoCodecIDOn2VP6=4,
    LFPlayVideoCodecIDOn2VP6WithAlphaChannel=5,
    LFPlayVideoCodecIDScreenVideoVersion=6,
    LFPlayVideoCodecIDAVC=7 //h264编解码器
} LFPlayVideoCodecIDType;

/**
 *  播放配置信息
 */
@interface LFPlayConfig : NSObject
/**
 *  分辨率宽
 */
@property (assign,nonatomic) int width;
/**
 *  分辨率高
 */
@property (assign,nonatomic) int height;
/**
 *  视频码率
 */
@property (assign,nonatomic) int videodatarate;
/**
 *  视频帧率
 */
@property (assign,nonatomic) int framerate;
/**
 *  视频编码格式 编码格式7代表h264
 */
@property (assign,nonatomic) int videocodecid;
/**
 *  音频码率
 */
@property (assign,nonatomic) int audiodatarate;
/**
 *  音频采样率
 */
@property (assign,nonatomic) int audiosamplerate;
/**
 *  音频flv封包采样率
 */
@property (assign,nonatomic) int flvTagAudiosamplerate;
/**
 *  音频位元深度
 */
@property (assign,nonatomic) int audiosamplesize;
/**
 *  是否立体声
 */
@property (assign,nonatomic) BOOL stereo;
/**
 *  音频编码格式 10代表aac
 */
@property (assign,nonatomic) LFPlayAudioFormat audiocodecid;

/**
 *  音频采样格式描述符
 */
@property (assign,nonatomic) LFPlayAudioSamplerate audioSamplerateid;
/**
 *  AAC编码类型
 */
@property (assign,nonatomic) LFPlayAACProfile aacProfile;

/**
 *  视频帧类型
 */
@property (assign,nonatomic) LFPlayVideoFrameType frameType;
/**
 *  视频编解码器类型
 */
@property (assign,nonatomic) LFPlayVideoCodecIDType codecID;
/**
 *  h264编码的sps数据
 */
@property (strong,nonatomic) NSMutableData *sps;
/**
 *  h264编码的pps数据
 */
@property (strong,nonatomic) NSMutableData *pps;
/**
 *  将音频相关数据组合成AudioStreamBasicDescription
 *  @return AudioStreamBasicDescription
 */
-(AudioStreamBasicDescription)getAudioStreamBasicDescription;
/**
 *  AAC的ADTS头
 */
-(NSData *)getAACADTS:(NSUInteger)aacDataLength;
/**
 *  音频编码格式描述
 *  @param audiocodecid 音频编码格式描述符
 */
+(NSString *)getAudioFormatDes:(LFPlayAudioFormat)audiocodecid;
/**
 *  视频帧类型描述
 *  @param frameType 视频帧类型描述
 */
+(NSString *)getVideoFrameTypeDes:(LFPlayVideoFrameType)frameType;
/**
 *  视频编解码器类型描述
 *  @param codecID 视频编解码器类型描述
 */
+(NSString *)getVideoCodecIDDes:(LFPlayVideoCodecIDType)codecID;

@end
