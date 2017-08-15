//
//  LFVideoConfig.m
//  myrtmp
//
//  Created by liuf on 16/8/4.
// 
//

#import "LFVideoConfig.h"
#import <AVFoundation/AVFoundation.h>
@implementation LFVideoConfig

/**
 *  通过默认配置实例化
 *
 *  @return self
 */
+(instancetype)defaultConfig{
    return [[LFVideoConfig alloc] init:LFVideoConfigQuality_Default isLandscape:NO];
}

/**
 *  通过LFVideoConfigQuality初始化
 *
 *  @param quality 视频质量
 *  @param isLandscape 是否横屏
 *  @return self
 */
-(instancetype)init:(LFVideoConfigQuality)quality isLandscape:(BOOL)isLandscape{
    self=[super init];
    if(self){
        _isLandscape=isLandscape;
        [self splitConfig:quality];
        [self checkDeviceResolution];
    }
    return self;
}

/**
 *  拆分配置
 *
 *  @param quality 配置
 */
-(void)splitConfig:(LFVideoConfigQuality)quality{
    switch (quality) {
        case LFVideoConfigQuality_Low1:
        {
            _frameRate=15;
            _maxFrameRate=15;
            _minFrameRate=10;
            _bitRate=500*1000;
            _maxBitRate=600*1000;
            _minBitRate=400*1000;
            _resolution=LFVideoConfigResolution360_640;
            if(_isLandscape){
                _videoSize=CGSizeMake(640, 360);
            }else{
                _videoSize=CGSizeMake(360, 640);
            }
        }
            break;
        case LFVideoConfigQuality_Low2:
        {
            _frameRate=24;
            _maxFrameRate=24;
            _minFrameRate=12;
            _bitRate=600*1000;
            _maxBitRate=720*1000;
            _minBitRate=500*1000;
            _resolution=LFVideoConfigResolution360_640;
            if(_isLandscape){
                _videoSize=CGSizeMake(640, 360);
            }else{
                _videoSize=CGSizeMake(360, 640);
            }
        }
            break;
        case LFVideoConfigQuality_Low3:
        {
            _frameRate=30;
            _maxFrameRate=30;
            _minFrameRate=15;
            _bitRate=800*1000;
            _maxBitRate=960*1000;
            _minBitRate=600*1000;
            _resolution=LFVideoConfigResolution360_640;
            if(_isLandscape){
                _videoSize=CGSizeMake(640, 360);
            }else{
                _videoSize=CGSizeMake(360, 640);
            }
        }
            break;
        case LFVideoConfigQuality_Middle1:
        {
            _frameRate=15;
            _maxFrameRate=15;
            _minFrameRate=10;
            _bitRate=800*1000;
            _maxBitRate=960*1000;
            _minBitRate=500*1000;
            _resolution=LFVideoConfigResolution540_960;
            if(_isLandscape){
                _videoSize=CGSizeMake(960, 540);
            }else{
                _videoSize=CGSizeMake(540, 960);
            }
        }
            break;
        case LFVideoConfigQuality_Middle2:
        {
            _frameRate=24;
            _maxFrameRate=24;
            _minFrameRate=12;
            _bitRate=800*1000;
            _maxBitRate=960*1000;
            _minBitRate=500*1000;
            _resolution=LFVideoConfigResolution540_960;
            if(_isLandscape){
                _videoSize=CGSizeMake(960, 540);
            }else{
                _videoSize=CGSizeMake(540, 960);
            }
        }
            break;
        case LFVideoConfigQuality_Middle3:
        {
            _frameRate=30;
            _maxFrameRate=30;
            _minFrameRate=15;
            _bitRate=1000*1000;
            _maxBitRate=1200*1000;
            _minBitRate=500*1000;
            _resolution=LFVideoConfigResolution540_960;
            if(_isLandscape){
                _videoSize=CGSizeMake(960, 540);
            }else{
                _videoSize=CGSizeMake(540, 960);
            }
        }
            break;
        case LFVideoConfigQuality_Hight1:
        {
            _frameRate=15;
            _maxFrameRate=15;
            _minFrameRate=10;
            _bitRate=1000*1000;
            _maxBitRate=1200*1000;
            _minBitRate=500*1000;
            _resolution=LFVideoConfigResolution720_1280;
            if(_isLandscape){
                _videoSize=CGSizeMake(1280,720);
            }else{
                _videoSize=CGSizeMake(720,1280);
            }
        }
            break;
        case LFVideoConfigQuality_Hight2:
        {
            _frameRate=24;
            _maxFrameRate=24;
            _minFrameRate=12;
            _bitRate=1000*1000;
            _maxBitRate=1440*1000;
            _minBitRate=800*1000;
            _resolution=LFVideoConfigResolution720_1280;
            if(_isLandscape){
                _videoSize=CGSizeMake(1280,720);
            }else{
                _videoSize=CGSizeMake(720,1280);
            }
        }
            break;
        case LFVideoConfigQuality_Hight3:
        {
            _frameRate=30;
            _maxFrameRate=30;
            _minFrameRate=15;
            _bitRate=1200*1000;
            _maxBitRate=1440*1000;
            _minBitRate=500*1000;
            _resolution=LFVideoConfigResolution720_1280;
            if(_isLandscape){
                _videoSize=CGSizeMake(1280,720);
            }else{
                _videoSize=CGSizeMake(720,1280);
            }
        }
            break;
        default:
            break;
    }
    _maxKeyframeInterval=2*_frameRate;
    
}

/**
 *  检查设备对分辨率的支持情况
 */
-(void)checkDeviceResolution{
    switch (_resolution) {
        case LFVideoConfigResolution360_640:
        {
            _videoSessionPreset=AVCaptureSessionPreset640x480;
            
        }
            break;
        case LFVideoConfigResolution540_960:
        {
            _videoSessionPreset=AVCaptureSessionPresetiFrame960x540;
        }
            break;
        case LFVideoConfigResolution720_1280:
        {
            _videoSessionPreset=AVCaptureSessionPresetiFrame1280x720;
        }
            break;
        default:
            break;
    }
    AVCaptureSession *session=[[AVCaptureSession alloc] init];
    if(![session canSetSessionPreset:_videoSessionPreset]){
        if(_resolution==LFVideoConfigResolution720_1280){
            _resolution=LFVideoConfigResolution540_960;
            _videoSessionPreset=AVCaptureSessionPresetiFrame960x540;
            if(![session canSetSessionPreset:_videoSessionPreset]){
                _resolution=LFVideoConfigResolution360_640;
                _videoSessionPreset=AVCaptureSessionPreset640x480;
            }
        }else{
            _resolution=LFVideoConfigResolution360_640;
            _videoSessionPreset=AVCaptureSessionPreset640x480;
        }
    }
}
@end
