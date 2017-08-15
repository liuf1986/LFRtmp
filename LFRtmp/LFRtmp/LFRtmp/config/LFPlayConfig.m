//
//  LFPlayConfig.m
//  LFRtmp
//
//  Created by liuf on 2017/5/11.
//  Copyright © 2017年 liufang. All rights reserved.
//

#import "LFPlayConfig.h"

@implementation LFPlayConfig

-(instancetype)init{
    self=[super init];
    if(self){
        self.aacProfile=LFPlayAACProfileAACLC;
    }
    return self;
}
/**
 *  将音频相关数据组合成AudioStreamBasicDescription
 *  @return AudioStreamBasicDescription
 */
-(AudioStreamBasicDescription)getAudioStreamBasicDescription{
    AudioStreamBasicDescription asbDes={0};
    //音频流描述    
    asbDes.mSampleRate = _audiosamplerate;
    asbDes.mFormatID = [self getAudioFormatDes];
    asbDes.mFormatFlags = 0;
    asbDes.mBytesPerPacket = 0;
    asbDes.mFramesPerPacket = 1024;
    asbDes.mBytesPerFrame = 0;
    asbDes.mChannelsPerFrame = _stereo?2:1;
    asbDes.mBitsPerChannel = 0;
    asbDes.mReserved = 0;
    return asbDes;

}
/**
 *  音频编码格式对应在iOS系统中的AudioFormatID
 */
-(AudioFormatID)getAudioFormatDes{
    AudioFormatID formatId=kAudioFormatLinearPCM;
    switch (_audiocodecid) {
        case LFPlayAudioFormatPCMPlatformEndian:
        {
            formatId=kAudioFormatLinearPCM;
        }
            break;
        case LFPlayAudioFormatADPCM:
        {
            formatId=kAudioFormatLinearPCM;
        }
            break;
        case LFPlayAudioFormatMP3:
        {
            formatId=kAudioFormatMPEGLayer3;
        }
            break;
        case LFPlayAudioFormatPCMLittleEndian:
        {
            formatId=kAudioFormatLinearPCM;
        }
            break;
        case LFPlayAudioFormatNellymoser16kHzMono:
        {
            NSLog(@"--------------LFPlayConfig：未找到LFPlayAudioFormatNellymoser16kHzMono对应格式，尝试使用PCM！--------------");
        }
            break;
        case LFPlayAudioFormatNellymoser8kHzMono:
        {
            NSLog(@"--------------LFPlayConfig：未找到LFPlayAudioFormatNellymoser8kHzMono对应格式，尝试使用PCM！--------------");
        }
            break;
        case LFPlayAudioFormatNellymoser:
        {
            NSLog(@"--------------LFPlayConfig：未找到LFPlayAudioFormatNellymoser对应格式，尝试使用PCM！--------------");
        }
            break;
        case LFPlayAudioFormatPCMG711AlawLogarithmic:
        {
            NSLog(@"--------------LFPlayConfig：未找到LFPlayAudioFormatPCMG711AlawLogarithmic对应格式，尝试使用PCM！--------------");
        }
            break;
        case LFPlayAudioFormatPCMG711MulawLogarithmic:
        {
            NSLog(@"--------------LFPlayConfig：未找到LFPlayAudioFormatPCMG711AlawLogarithmic对应格式，尝试使用PCM！--------------");
        }
            break;
        case LFPlayAudioFormatReserved:
        {
            NSLog(@"--------------LFPlayConfig：未找到LFPlayAudioFormatPCMG711AlawLogarithmic对应格式，尝试使用PCM！--------------");
        }
            break;
        case LFPlayAudioFormatAAC:
        {
            formatId=kAudioFormatMPEG4AAC;
        }
            break;
        case LFPlayAudioFormatSpeex:
        {
            NSLog(@"--------------LFPlayConfig：未找到LFPlayAudioFormatPCMG711AlawLogarithmic对应格式，尝试使用PCM！--------------");
        }
            break;
        case LFPlayAudioFormatMP38kHz:
        {
            NSLog(@"--------------LFPlayConfig：未找到LFPlayAudioFormatPCMG711AlawLogarithmic对应格式，尝试使用PCM！--------------");
        }
            break;
        case LFPlayAudioFormatDeviceSpecificSound:
        {
            NSLog(@"--------------LFPlayConfig：未找到LFPlayAudioFormatPCMG711AlawLogarithmic对应格式，尝试使用PCM！--------------");
        }
            break;
    }
    return formatId;
}
/**
 *  AAC的ADTS头，在播放端获取的aac数据时并不能直接被硬件播放而是需要添加adts头
 */
-(NSData *)getAACADTS:(NSUInteger)aacDataLength{
    /*
     ADTS数据长度为7位，如果有crc则为9位
     ADTS头的构成为
     1：syncword：12位 全为1表示一个ADTS开始的标示
     2：ID  1位 MPEG Version: 0 for MPEG-4, 1 for MPEG-2
     3：Layer：2位 always: '00'
     4：缺位保护: 1位 如果是CRC设为0，否则设置为1
     5：AAC编码的profile：2位 表示使用哪个级别的AAC，有些芯片只支持AAC LC 。如果是mp4则为当前编码类型减1
             1: AAC Main
             2: AAC LC (Low Complexity)
             3: AAC SSR (Scalable Sample Rate)
     6：采样率  4位
             0: 96000 Hz
             1: 88200 Hz
             2: 64000 Hz
             3: 48000 Hz
             4: 44100 Hz
             5: 32000 Hz
             6: 24000 Hz
             7: 22050 Hz
             8: 16000 Hz
             9: 12000 Hz
             10: 11025 Hz
             11: 8000 Hz
             12: 7350 Hz
             13: Reserved
             14: Reserved
             15: frequency is written explictly
     7：private_bite:1位，编码设置为0，解码忽略
     8：声道数 ：3位
             0: Defined in AOT Specifc Config
             1: 1 channel: front-center
             2: 2 channels: front-left, front-right
             3: 3 channels: front-center, front-left, front-right
             4: 4 channels: front-center, front-left, front-right, back-center
             5: 5 channels: front-center, front-left, front-right, back-left, back-right
             6: 6 channels: front-center, front-left, front-right, back-left, back-right, LFE-channel
             7: 8 channels: front-center, front-left, front-right, side-left, side-right, back-left, back-right, LFE-channel
             8-15: Reserved
     9：originality 1位 编码时设置为0，解码忽略
     10：home 1位 编码时设置为0，解码忽略
     11：版权id 1位 编码设置为0，解码忽略
     12：版权ID开始 1位 编码设置为0，解码忽略
     13：ADTS帧长度，如果缺位保护值为1则ADTS帧长度=7+AAC数据长度，否则ADTS帧长度=9+AAC数据长度
     14：Buffer fullness 11位 0x7FF 说明是码率可变的码流
     15：AAC的帧的数目 2位 
     16：CRC数据 16位 这个数据是在缺位保护为0时才存在，这也是为什么ADTS长度是7或者9
     */
    short int bufferFullness=0x7FF;
    char channel=_stereo?2:1;
    short int fullLength = kLFPlayConfigADTSLength + aacDataLength;
    NSMutableData *data=[NSMutableData new];
    [data setLength:kLFPlayConfigADTSLength];
    uint8_t *bytes=data.mutableBytes;
    bytes[0]=(char)0xFF; // 11111111     syncword前8位
    bytes[1]=(char)0xF1; // 1111 0 00 1  syncword后四位 MPEG-4 Layer CRC
    bytes[2]=(((char)(_aacProfile-1))<<6)|((((char)_audioSamplerateid)<<4)>>2)|0x0|(((char)channel)>>2);
    bytes[3]=(((char)channel)<<6)|((char)((fullLength<<3)>>14));
    bytes[4]=(char)((fullLength<<5)>>8);
    bytes[5]=((char)((fullLength<<13)>>8))|((char)((bufferFullness<<5)>>11));
    bytes[6]=(char)((bufferFullness<<10)>>8);
    return data;
}
/**
 *  音频编码格式描述
 */
+(NSString *)getAudioFormatDes:(LFPlayAudioFormat)audiocodecid{
    NSString *soundFormat=nil;
    switch (audiocodecid) {
        case LFPlayAudioFormatPCMPlatformEndian:
        {
            soundFormat=@"Linear PCM, platform endian";
        }
            break;
        case LFPlayAudioFormatADPCM:
        {
            soundFormat=@"ADPCM";
        }
            break;
        case LFPlayAudioFormatMP3:
        {
            soundFormat=@"MP3";
        }
            break;
        case LFPlayAudioFormatPCMLittleEndian:
        {
            soundFormat=@" Linear PCM, little endian";
        }
            break;
        case LFPlayAudioFormatNellymoser16kHzMono:
        {
            soundFormat=@"Nellymoser 16 kHz mono";
        }
            break;
        case LFPlayAudioFormatNellymoser8kHzMono:
        {
            soundFormat=@"Nellymoser 8 kHz mono";
        }
            break;
        case LFPlayAudioFormatNellymoser:
        {
            soundFormat=@"Nellymoser";
        }
            break;
        case LFPlayAudioFormatPCMG711AlawLogarithmic:
        {
            soundFormat=@" G.711 A-law logarithmic PCM";
        }
            break;
        case LFPlayAudioFormatPCMG711MulawLogarithmic:
        {
            soundFormat=@"G.711 mu-law logarithmic PCM";
        }
            break;
        case LFPlayAudioFormatReserved:
        {
            soundFormat=@"reserved";
        }
            break;
        case LFPlayAudioFormatAAC:
        {
            soundFormat=@"AAC";
        }
            break;
        case LFPlayAudioFormatSpeex:
        {
            soundFormat=@"Speex";
        }
            break;
        case LFPlayAudioFormatMP38kHz:
        {
            soundFormat=@"MP3 8 kHz";
        }
            break;
        case LFPlayAudioFormatDeviceSpecificSound:
        {
            soundFormat=@"Device-specific sound";
        }
            break;
        default:
        {
            soundFormat=@"未知类型";
        }
            break;
    }
    return soundFormat;
}
+(NSString *)getVideoFrameTypeDes:(LFPlayVideoFrameType)frameType{
    NSString *frameTypeDes=nil;
    switch (frameType) {
        case LFPlayVideoFrameKeyFrame:
        {
            frameTypeDes=@"key frame";
        }
            break;
        case LFPlayVideoFrameInterFrame:
        {
            frameTypeDes=@"inter Frame";
        }
            break;
        case LFPlayVideoFrameGeneratedKeyFrame:
        {
            frameTypeDes=@"generated key frame";
        }
            break;
        case LFPlayVideoFrameDisposableInterFrame:
        {
            frameTypeDes=@"disposable inter frame";
        }
            break;
        case LFPlayVideoFrameVideoInfoOrCommandFrame:
        {
            frameTypeDes=@"videoInfo/command frame";
        }
            break;
        default:
        {
            frameTypeDes=@"未知类型";
        }
            break;
    }
    return frameTypeDes;
}
/**
 *  视频编解码器类型描述
 *  @param codecID 视频编解码器类型描述
 */
+(NSString *)getVideoCodecIDDes:(LFPlayVideoCodecIDType)codecID{
    NSString *codecIDDes=nil;
    switch (codecID) {
        case LFPlayVideoCodecIDJPEG:
        {
            codecIDDes=@"JPEG";
        }
            break;
        case LFPlayVideoCodecIDH263:
        {
            codecIDDes=@"H263";
        }
            break;
        case LFPlayVideoCodecIDScreenVideo:
        {
            codecIDDes=@"ScreenVideo";
        }
            break;
        case LFPlayVideoCodecIDOn2VP6:
        {
            codecIDDes=@"On2VP6";
        }
            break;
        case LFPlayVideoCodecIDOn2VP6WithAlphaChannel:
        {
            codecIDDes=@"On2VP6WithAlphaChannel";
        }
            break;
        case LFPlayVideoCodecIDScreenVideoVersion:
        {
            codecIDDes=@"ScreenVideoVersion";
        }
            break;
        case LFPlayVideoCodecIDAVC:
        {
            codecIDDes=@"AVC(h264)";
        }
            break;
        default:
        {
            codecIDDes=@"未知类型";
        }
            break;
    }
    return codecIDDes;
}
/**
 *  通过
 *  @param audioSamplerate 音频采样格式描述符
 */
-(void)setAudioSamplerateid:(LFPlayAudioSamplerate)audioSamplerateid{
    _audioSamplerateid=audioSamplerateid;
    switch (audioSamplerateid) {
        case LFPlayAudioSamplerate96000:
        {
            self.audiosamplerate=96000;
        }
            break;
        case LFPlayAudioSamplerate88200:
        {
            self.audiosamplerate=88200;
        }
            break;
        case LFPlayAudioSamplerate64000:
        {
            self.audiosamplerate=64000;
        }
            break;
        case LFPlayAudioSamplerate48000:
        {
            self.audiosamplerate=48000;
        }
            break;
        case LFPlayAudioSamplerate44100:
        {
            self.audiosamplerate=44100;
        }
            break;
        case LFPlayAudioSamplerate32000:
        {
            self.audiosamplerate=32000;
        }
            break;
        case LFPlayAudioSamplerate24000:
        {
            self.audiosamplerate=24000;
        }
            break;
        case LFPlayAudioSamplerate22050:
        {
            self.audiosamplerate=22050;
        }
            break;
        case LFPlayAudioSamplerate16000:
        {
            self.audiosamplerate=16000;
        }
            break;
        case LFPlayAudioSamplerate12000:
        {
            self.audiosamplerate=12000;
        }
            break;
        case LFPlayAudioSamplerate11025:
        {
            self.audiosamplerate=11025;
        }
            break;
        case LFPlayAudioSamplerate8000:
        {
            self.audiosamplerate=8000;
        }
            break;
        default:
            break;
    }
}
- (void)setValue:(id)value forUndefinedKey:(NSString *)key{
}
@end
