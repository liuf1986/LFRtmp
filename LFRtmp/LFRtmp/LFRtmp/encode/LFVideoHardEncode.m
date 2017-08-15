//
//  LFVideoHardEncode.m
//  myrtmp
//
//  Created by liuf on 16/8/12.
//
//

#import "LFVideoHardEncode.h"
#import <VideoToolbox/VideoToolbox.h>
@implementation LFVideoHardEncode
{
    LFVideoConfig *_videoConfig;
    VTCompressionSessionRef _compressionSession;
    NSInteger _frameCount;
    NSData *_sps;
    NSData *_pps;
    BOOL _isBackgroud;
    __weak id<LFVideoEncodeDelegate> _delegate;
}
/**
 *  初始化
 */
-(instancetype)init:(LFVideoConfig *)videoConfig{
    self=[super init];
    if(self){
        _videoConfig=videoConfig;
        [self configCompressSession];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(willEnterBackground:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(willEnterForeground:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    }
    return self;
}
/**
 *  配置VTCompressionSessionRef
 */
-(void)configCompressSession{
    [self stopEncode];
    //创建编码器
    OSStatus status=VTCompressionSessionCreate(NULL,
                                               _videoConfig.videoSize.width,
                                               _videoConfig.videoSize.height,
                                               kCMVideoCodecType_H264,
                                               NULL,
                                               NULL,
                                               NULL,
                                               compressonOutputCallback,
                                               (__bridge void * _Nullable)(self),
                                               &_compressionSession);
    if(status!=noErr){
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                             code:status
                                         userInfo:nil];
        NSLog(@"-------------创建视频硬件编码器失败：%@！------------- ", [error description]);
    }else{
        VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(_videoConfig.maxKeyframeInterval));
        VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, (__bridge CFTypeRef)@(_videoConfig.maxKeyframeInterval));
        VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(_videoConfig.frameRate));
        VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(_videoConfig.bitRate));
        NSArray *limit = @[@(_videoConfig.bitRate * 1.5/8), @(1)];
        VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
        VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanFalse);
        VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel);
        VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
        VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_H264EntropyMode, kVTH264EntropyMode_CABAC);
        VTCompressionSessionPrepareToEncodeFrames(_compressionSession);
    }
}

/**
 *  编码输出
 */
static void compressonOutputCallback(void *VTref, void *VTFrameRef, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer){
    if (!sampleBuffer) return;
    CFArrayRef array = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    if (!array) return;
    CFDictionaryRef dic = (CFDictionaryRef)CFArrayGetValueAtIndex(array, 0);
    if (!dic) return;
    
    BOOL keyframe = !CFDictionaryContainsKey(dic, kCMSampleAttachmentKey_NotSync);
    uint64_t timeStamp = [((__bridge_transfer NSNumber *)VTFrameRef) longLongValue];
    
    LFVideoHardEncode*videoEncoder = (__bridge LFVideoHardEncode *)VTref;
    if (status != noErr) {
        return;
    }
    
    if (keyframe && !videoEncoder->_sps) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0);
        if (statusCode == noErr) {
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0);
            if (statusCode == noErr) {
                videoEncoder->_sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                videoEncoder->_pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
            }
        }
    }
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            LFVideoEncodeInfo *info = [LFVideoEncodeInfo new];
            info.timeStamp =(uint32_t)timeStamp;
            info.data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            info.isKeyFrame = keyframe;
            info.sps = videoEncoder->_sps;
            info.pps = videoEncoder->_pps;
            if (videoEncoder->_delegate) {
                [videoEncoder->_delegate onDidVideoEncodeOutput:info];
            }
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}
/**
 *  h264编码
 */
-(void)encode:(CVImageBufferRef)buffer timeStamp:(uint64_t)timeStamp{
    if (_isBackgroud){
        return;
    }
    _frameCount++;
    CMTime presentationTimeStamp = CMTimeMake(_frameCount, 1000);
    VTEncodeInfoFlags flags;
    CMTime duration = CMTimeMake(1, (int32_t)_videoConfig.frameRate);
    NSDictionary *properties = nil;
    if (_frameCount % (int32_t)_videoConfig.maxKeyframeInterval == 0) {
        properties = @{(__bridge NSString *)kVTEncodeFrameOptionKey_ForceKeyFrame: @YES};
    }
    NSNumber *timeNumber = @(timeStamp);
    //开始编码
    VTCompressionSessionEncodeFrame(_compressionSession, buffer, presentationTimeStamp, duration, (__bridge CFDictionaryRef)properties, (__bridge_retained void *)timeNumber, &flags);
}

/**
 *  编码数据输出代理
 */
-(void)setDelegate:(id<LFVideoEncodeDelegate>)delegate{
    _delegate=delegate;
}
/**
 *  停止编码
 */
- (void)stopEncode{
    if(_compressionSession){
        VTCompressionSessionCompleteFrames(_compressionSession, kCMTimeInvalid);
        
        VTCompressionSessionInvalidate(_compressionSession);
        CFRelease(_compressionSession);
        _compressionSession = NULL;
    }
}

#pragma mark -- handler notification
- (void)willEnterBackground:(NSNotification *)notification {
    _isBackgroud = YES;
}

- (void)willEnterForeground:(NSNotification *)notification {
    [self configCompressSession];
    _isBackgroud = NO;
}
-(void)dealloc{
    [self stopEncode];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillResignActiveNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
    
}
@end
