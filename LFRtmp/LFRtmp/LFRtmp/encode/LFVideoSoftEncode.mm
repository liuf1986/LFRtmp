//
//  LFVideoSoftEncode.m
//  myrtmp
//
//  Created by liuf on 16/8/12.
// 
//

#import "LFVideoSoftEncode.h"
#import "AVEncoder.h"
#import "NALUnit.h"
#import "LFVideoEncodeInfo.h"
@implementation LFVideoSoftEncode
{
    LFVideoConfig *_videoConfig;
    NSInteger _frameCount;
    NSData *_naluData;
    AVEncoder *_encoder;
    NSMutableData *_sps;
    NSMutableData *_pps;
    NSMutableData *_videoSPSandPPS;
    NSMutableData *_sei;
    BOOL _isBackgroud;
    __weak  id<LFVideoEncodeDelegate> _delegate;
}
/**
 *  初始化
 */
-(instancetype)init:(LFVideoConfig *)videoConfig{
    self=[super init];
    if(self){
        _videoConfig=videoConfig;
        _frameCount = 0;
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
 *  配置软编码器
 */
-(void)configCompressSession{
    //配置NALU
    NSUInteger naluLength = 4;
    uint8_t *nalu = (uint8_t*)malloc(naluLength * sizeof(uint8_t));
    nalu[0] = 0x00;
    nalu[1] = 0x00;
    nalu[2] = 0x00;
    nalu[3] = 0x01;
    _naluData = [NSData dataWithBytesNoCopy:nalu length:naluLength freeWhenDone:YES];
    //初始化编码器
    __weak __typeof(self)weakSelf = self;
    _encoder=[AVEncoder encoderForHeight:_videoConfig.videoSize.height
                                andWidth:_videoConfig.videoSize.width
                                 bitrate:_videoConfig.bitRate];
    //配置编码器回调
    [_encoder encodeWithBlock:^int(NSArray *data, CMTimeValue ptsValue) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        [strongSelf inputFrames:data ptsValue:ptsValue];
        return 0;
    } onParams:^int(NSData *params) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        [strongSelf handParams];
        return 0;
    }];
}
/**
 * 输入的视频帧处理
 */
-(void)inputFrames:(NSArray *)frames ptsValue:(CMTimeValue)ptsValue{
    if(ptsValue!=0){
        if (!_videoSPSandPPS) {
            [self handParams];
        }
        CMTime pts=CMTimeMake(ptsValue, 1000);
        NSMutableData *aggregateFrameData=[NSMutableData data];
        for (NSData *data in frames) {
            unsigned char* pNal=(unsigned char*)[data bytes];
            int idc=pNal[0] & 0x60;
            int naltype=pNal[0] & 0x1f;
            NSData *videoData = nil;
            if (idc==0&&naltype==6) {
                _sei=[NSMutableData dataWithData:data];
                continue;
            } else if (naltype==5) {
                NSMutableData *IDRData=[NSMutableData dataWithData:_videoSPSandPPS];
                if (_sei) {
                    [IDRData appendData:_naluData];
                    [IDRData appendData:_sei];
                    _sei = nil;
                }
                [IDRData appendData:_naluData];
                [IDRData appendData:data];
                videoData = IDRData;
            } else {
                NSMutableData *regularData=[NSMutableData dataWithData:_naluData];
                [regularData appendData:data];
                videoData=regularData;
            }
            [aggregateFrameData appendData:videoData];
            LFVideoEncodeInfo *info=[[LFVideoEncodeInfo alloc] init];
            const char *dataBuffer=(const char *)aggregateFrameData.bytes;
            info.data=[NSMutableData dataWithBytes:dataBuffer + _naluData.length length:aggregateFrameData.length - _naluData.length];
            info.timeStamp=(uint32_t)pts.value;
            info.isKeyFrame=(naltype == 5);
            info.sps=_sps;
            info.pps=_pps;
            if(_delegate){
                [_delegate onDidVideoEncodeOutput:info];
            }
        }
    }
    
}
/**
 *  获取pps和sps数据
 */
-(void)handParams{
    NSData* config =_encoder.getConfigData;
    if (!config) {
        return;
    }
    avcCHeader avcC((const BYTE*)[config bytes], (int)[config length]);
    SeqParamSet seqParams;
    seqParams.Parse(avcC.sps());
    NSData* spsData=[NSData dataWithBytes:avcC.sps()->Start() length:avcC.sps()->Length()];
    NSData *ppsData=[NSData dataWithBytes:avcC.pps()->Start() length:avcC.pps()->Length()];
    _sps=[NSMutableData dataWithCapacity:avcC.sps()->Length()+_naluData.length];
    _pps=[NSMutableData dataWithCapacity:avcC.pps()->Length()+_naluData.length];
    [_sps appendData:_naluData];
    [_sps appendData:spsData];
    [_pps appendData:_naluData];
    [_pps appendData:ppsData];
    
    _videoSPSandPPS = [NSMutableData dataWithCapacity:avcC.sps()->Length() + avcC.pps()->Length() + _naluData.length * 2];
    [_videoSPSandPPS appendData:_naluData];
    [_videoSPSandPPS appendData:spsData];
    [_videoSPSandPPS appendData:_naluData];
    [_videoSPSandPPS appendData:ppsData];
}

/**
 *  h264编码
 */
-(void)encode:(CVImageBufferRef)buffer timeStamp:(uint64_t)timeStamp{
    if (_isBackgroud){
        return;
    }
    CVPixelBufferLockBaseAddress(buffer, 0);
    CMVideoFormatDescriptionRef videoInfo = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(NULL, buffer, &videoInfo);
    CMTime frameTime = CMTimeMake(timeStamp, 1000);
    CMTime duration = CMTimeMake(1, (int32_t)_videoConfig.frameRate);
    CMSampleTimingInfo timing = {duration, frameTime, kCMTimeInvalid};
    CMSampleBufferRef sampleBuffer = NULL;
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, buffer, YES, NULL, NULL, videoInfo, &timing, &sampleBuffer);
    CVPixelBufferUnlockBaseAddress(buffer, 0);
    [_encoder encodeFrame:sampleBuffer];
    CFRelease(videoInfo);
    CFRelease(sampleBuffer);
    _frameCount++;
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
    [_encoder encodeWithBlock:nil onParams:nil];
}
#pragma mark -- handler notification
- (void)willEnterBackground:(NSNotification *)notification {
    _isBackgroud = YES;
}

- (void)willEnterForeground:(NSNotification *)notification {
    _isBackgroud = NO;
}
- (void) dealloc {
    [self stopEncode];
    [_encoder shutdown];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillResignActiveNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
}
@end
