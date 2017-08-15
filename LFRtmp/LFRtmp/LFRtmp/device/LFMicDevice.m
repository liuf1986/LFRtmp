//
//  LFMicDevice.m
//  myrtmp
//
//  Created by liuf on 16/8/3.
// 
//

#import "LFMicDevice.h"
@interface LFMicDevice()
/**
 *  AudioComponentInstance实例
 */
@property (assign,nonatomic) AudioComponentInstance audioComInstance;
@end
@implementation LFMicDevice
{
    LFAudioConfig *_audioConfig;
}
/**
 *  初始化
 *  @param audioConfig 音频采样配置
 */
-(instancetype)init:(LFAudioConfig *)audioConfig;{
    self=[super init];
    if(self){
        _audioConfig=audioConfig;
        [self configMicDevice];
    }
    return self;
}
/**
 设置代理
 
 @param delegate NetServerDelegate
 */
-(void)setDelegate:(id<LFMicDeviceDelegate>)delegate{
    _delegate=delegate;
    if (_delegate) {
        _delegateFlags.isExistOnMicOutputData=[_delegate respondsToSelector:@selector(onMicOutputData:)];
    } else {
        _delegateFlags.isExistOnMicOutputData=0;
    }
}
/**
 *  配置麦克
 */
-(void)configMicDevice{
    AVAudioSession *session=[AVAudioSession sharedInstance];
    [session requestRecordPermission:^(BOOL granted) {
        if(granted){
           [session setCategory:AVAudioSessionCategoryPlayAndRecord
                    withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionMixWithOthers
                          error:nil];
            [session setActive:YES error:nil];
            //配置音频组件描述
            AudioComponentDescription acDes;
            acDes.componentType=kAudioUnitType_Output;
            acDes.componentSubType=kAudioUnitSubType_RemoteIO;
            acDes.componentManufacturer=kAudioUnitManufacturer_Apple;
            acDes.componentFlags=0;
            acDes.componentFlagsMask=0;
            AudioComponent audioComponent=AudioComponentFindNext(NULL, &acDes);
            //获取组件实例
            AudioComponentInstanceNew(audioComponent, &_audioComInstance);
            UInt32 one=1;
            AudioUnitSetProperty(_audioComInstance,
                                 kAudioOutputUnitProperty_EnableIO,
                                 kAudioUnitScope_Input,
                                 1, &one, sizeof(one));
            //音频流描述
            AudioStreamBasicDescription asbDes={0};
            asbDes.mSampleRate=_audioConfig.sampleRate;
            asbDes.mFormatID=kAudioFormatLinearPCM;
            asbDes.mFormatFlags=(kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked);
            asbDes.mChannelsPerFrame=_audioConfig.channel;
            asbDes.mFramesPerPacket=1;
            asbDes.mBitsPerChannel=_audioConfig.bitDepth;
            asbDes.mBytesPerFrame=asbDes.mBitsPerChannel/8 * asbDes.mChannelsPerFrame;
            asbDes.mBytesPerPacket = asbDes.mBytesPerFrame * asbDes.mFramesPerPacket;
            AURenderCallbackStruct callback;
            callback.inputProcRefCon=(__bridge void * _Nullable)(self);
            callback.inputProc=inputProc;
            AudioUnitSetProperty(_audioComInstance,
                                 kAudioUnitProperty_StreamFormat,
                                 kAudioUnitScope_Output,
                                 1, &asbDes, sizeof(asbDes));
            AudioUnitSetProperty(_audioComInstance,
                                 kAudioOutputUnitProperty_SetInputCallback,
                                 kAudioUnitScope_Global,
                                 1, &callback, sizeof(callback));
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(handleInterruption:)
                                                         name:AVAudioSessionInterruptionNotification
                                                       object:nil];
            AudioUnitInitialize(_audioComInstance);
        }
    }];
}
/**
 *  AVAudioSessionInterruptionNotification监听
 *
 *  @param notification NSNotification
 */
-(void)handleInterruption:(NSNotification *)notification{
    NSDictionary *info=notification.userInfo;
    if([info[AVAudioSessionInterruptionTypeKey] intValue]==AVAudioSessionInterruptionTypeBegan){
        [self stopOutput];
    }else{
        [self startOuput];
    }
}
/**
 *  采集到的音频数据输出
 *
 *  @param data           音频数据
 *  @param size           数据大小
 *  @param inNumberFrames 样品帧的数量
 */
-(void)outputAudioData:(AudioBufferList)audioBufferList{
    if(_delegateFlags.isExistOnMicOutputData){
        [_delegate onMicOutputData:audioBufferList];
    }
}
/**
 *  停止采集
 */
-(void)stopOutput{
    OSStatus status=AudioOutputUnitStop(_audioComInstance);
    if(status!=noErr){
        NSLog(@"-------------停止音频采集失败！-------------");
    }
}
/**
 *  启动采集
 */
-(void)startOuput{
    AVAudioSession *session=[AVAudioSession sharedInstance];
    [session requestRecordPermission:^(BOOL granted) {
        if(granted){
            OSStatus status=AudioOutputUnitStart(_audioComInstance);
            if(status!=noErr){
                NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                                     code:status
                                                 userInfo:nil];
                NSLog(@"-------------启动音频采集失败：%@！------------- ", [error description]);
            }
        }
    }];
}
-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVAudioSessionInterruptionNotification
                                                  object:nil];
    AudioOutputUnitStop(_audioComInstance);
    AudioComponentInstanceDispose(_audioComInstance);
}
/**
 *  当音频输入时的回调
 */
static OSStatus inputProc(void *inRefCon,
                          AudioUnitRenderActionFlags *ioActionFlags,
                          const AudioTimeStamp *inTimeStamp,
                          UInt32 inBusNumber,
                          UInt32 inNumberFrames,
                          AudioBufferList *ioData){
    LFMicDevice *device=(__bridge LFMicDevice *)(inRefCon);
    AudioBuffer buffer;
    buffer.mData = NULL;
    buffer.mDataByteSize = 0;
    buffer.mNumberChannels = 2;
    AudioBufferList buffers;
    buffers.mNumberBuffers = 1;
    buffers.mBuffers[0] = buffer;
    OSStatus status = AudioUnitRender(device.audioComInstance,
                                      ioActionFlags,
                                      inTimeStamp,
                                      inBusNumber,
                                      inNumberFrames,
                                      &buffers);
    
    if(!status) {
        [device outputAudioData:buffers];
    }
    return status;
}
@end
