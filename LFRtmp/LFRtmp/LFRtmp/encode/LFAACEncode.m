//
//  LFAACEncode.m
//  myrtmp
//
//  Created by liuf on 16/8/3.
// 
//

#import "LFAACEncode.h"

@implementation LFAACEncode
{
    LFAudioConfig *_audioConfig;
    AudioConverterRef _audioConverter;
}
/**
 *  初始哈
 *
 *  @param audioConfig 音频配置信息
 *
 *  @return self
 */
-(instancetype)init:(LFAudioConfig *)audioConfig{
    self=[super init];
    if(self){
        _audioConfig=audioConfig;
        [self configAudioConverter];
    }
    return self;
}
/**
 *  AAC编码
 *
 *  @param audioBufferList audioBufferList
 *
 *  @return 返回经过AAC编码后的NSData
 */
-(NSData *)encode:(AudioBufferList)inputBuffer{
    NSData *data;
    uint8_t *buffer=malloc(inputBuffer.mBuffers[0].mDataByteSize);
    //配置输出缓冲区
    AudioBufferList outputBuffer;
    outputBuffer.mNumberBuffers=1;
    outputBuffer.mBuffers[0].mNumberChannels=inputBuffer.mBuffers[0].mNumberChannels;
    //设置缓冲区大小
    outputBuffer.mBuffers[0].mDataByteSize=inputBuffer.mBuffers[0].mDataByteSize;
    //设置缓冲区
    outputBuffer.mBuffers[0].mData=buffer;
    UInt32 packetSize=1;
    if(AudioConverterFillComplexBuffer(_audioConverter,inputDataProc, &inputBuffer, &packetSize, &outputBuffer, NULL)!=noErr){
        NSLog(@"-------------AAC编码失败！-------------");
        return nil;
    }
    data=[NSData dataWithBytes:buffer length:outputBuffer.mBuffers[0].mDataByteSize];
    free(buffer);
    return data;
}
/**
 *  输出转换器配置
 */
OSStatus inputDataProc (AudioConverterRef inAudioConverter,
                        UInt32 * ioNumberDataPackets,
                        AudioBufferList * outputBuffer,
                        AudioStreamPacketDescription * * outDataPacketDescription,
                        void * inUserData){
    //获取AudioConverterFillComplexBuffer中配置的input和output
    AudioBufferList inputBuffer= *(AudioBufferList *)inUserData;
    outputBuffer->mBuffers[0].mNumberChannels=1;
    outputBuffer->mBuffers[0].mData=inputBuffer.mBuffers[0].mData;
    outputBuffer->mBuffers[0].mDataByteSize=inputBuffer.mBuffers[0].mDataByteSize;
    return noErr;
}

/**
 *  配置PCM到AAC转换器
 */
-(void)configAudioConverter{
    //配置输入的音频格式,PCM格式
    AudioStreamBasicDescription inputDes={0};
    inputDes.mSampleRate=_audioConfig.sampleRate;
    inputDes.mFormatID=kAudioFormatLinearPCM;
    inputDes.mFormatFlags =(kAudioFormatFlagIsSignedInteger|kAudioFormatFlagsNativeEndian|kAudioFormatFlagIsPacked);
    inputDes.mChannelsPerFrame=_audioConfig.channel;
    inputDes.mFramesPerPacket=1;
    inputDes.mBitsPerChannel=_audioConfig.bitDepth;
    inputDes.mBytesPerFrame = inputDes.mBitsPerChannel / 8 * inputDes.mChannelsPerFrame;
    inputDes.mBytesPerPacket = inputDes.mBytesPerFrame * inputDes.mFramesPerPacket;
    //配置输出的音频格式，AAC格式
    AudioStreamBasicDescription outputDes={0};
    outputDes.mFormatFlags = 0;
    outputDes.mSampleRate=_audioConfig.sampleRate;
    outputDes.mFormatID=kAudioFormatMPEG4AAC;
    outputDes.mChannelsPerFrame=_audioConfig.channel;
    //AAC 一帧的数据为1024字节
    outputDes.mFramesPerPacket=1024;
    AudioClassDescription des[2]={
        {
            kAudioEncoderComponentType,
            kAudioFormatMPEG4AAC,
            kAppleSoftwareAudioCodecManufacturer
        },
        {
            kAudioEncoderComponentType,
            kAudioFormatMPEG4AAC,
            kAppleHardwareAudioCodecManufacturer
        }
    };
    OSStatus status=AudioConverterNewSpecific(&inputDes, &outputDes, 2, des, &_audioConverter);
    if(status!=noErr){
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                             code:status
                                         userInfo:nil];
        NSLog(@"-------------创建AAC编码器失败：%@！------------- ", [error description]);
    }
}
-(void)dealloc{
    if(AudioConverterDispose(_audioConverter)!=noErr){
        NSLog(@"-------------释放AAC编码器失败！-------------");
    }
    _audioConverter=NULL;
}
@end
