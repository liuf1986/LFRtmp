//
//  LFCameraDevice.m
//  myrtmp
//
//  Created by liuf on 16/8/3.
// 
//

#import "LFCameraDevice.h"
#import "GPUImage.h"
#import "LFBeautifulFilter.h"
#import "LFOriginalFilter.h"
#import "GPUImageStretchDistortionFilter.h"
#import "GPUImagePinchDistortionFilter.h"
#import "GPUImageVignetteFilter.h"
@interface LFCameraDevice()<GPUImageVideoCameraDelegate>
@end
@implementation LFCameraDevice
{
    GPUImageVideoCamera *_camera;
    GPUImageOutput<GPUImageInput> *_filter;
    GPUImageOutput<GPUImageInput> *_output;
    GPUImageView *_gpuImageView;
    LFVideoConfig *_videoConfig;
    GPUImageAlphaBlendFilter *_blendFilter;
    GPUImageUIElement *_uiElementInput;
    UIView *_uiContentView;
}
/**
 设置代理
 
 @param delegate NetServerDelegate
 */
-(void)setDelegate:(id<LFCameraDeviceDelegate>)delegate{
    _delegate=delegate;
    if (_delegate) {
        _delegateFlags.isExistonCameraOutputData=[_delegate respondsToSelector:@selector(onCameraOutputData:)];
    } else {
        _delegateFlags.isExistonCameraOutputData=0;
    }
}
/**
 *  初始化
 *
 *  @param videoConfig 音频采样配置
 */
-(instancetype)init:(LFVideoConfig *)videoConfig{
    self=[super init];
    if(self){
        _videoConfig=videoConfig;
        [self setVideoZoomScale:1.0 andError:nil andfinish:nil];
        [self configCamera];
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
 *  配置摄像头
 */
-(void)configCamera{
    if(!_camera){
        _camera=[[GPUImageVideoCamera alloc] initWithSessionPreset:_videoConfig.videoSessionPreset
                                                    cameraPosition:AVCaptureDevicePositionFront];
        if(_videoConfig.isLandscape){
            if(_orientation==UIInterfaceOrientationLandscapeLeft||_orientation==UIInterfaceOrientationLandscapeRight){
                _camera.outputImageOrientation=_orientation;
            }else{
                _camera.outputImageOrientation=UIInterfaceOrientationLandscapeLeft;
            }
        }else{
            if(_orientation==UIInterfaceOrientationPortrait||_orientation==UIInterfaceOrientationPortraitUpsideDown){
                _camera.outputImageOrientation=_orientation;
            }else{
                _camera.outputImageOrientation=UIInterfaceOrientationPortrait;
            }
        }
        _orientation=_camera.outputImageOrientation;
        _camera.horizontallyMirrorFrontFacingCamera=YES;
        _camera.horizontallyMirrorRearFacingCamera=NO;
        _camera.frameRate=_videoConfig.frameRate;
    }
    if(!_gpuImageView){
        _gpuImageView = [[GPUImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [_gpuImageView setFillMode:kGPUImageFillModePreserveAspectRatioAndFill];
    }
    if(!_uiContentView){
        _uiContentView = [UIView new];
        _uiContentView.frame = CGRectMake(0, 0, _gpuImageView.frame.size.width, _gpuImageView.frame.size.height);
    }
    if(!_uiElementInput){
        _uiElementInput=[[GPUImageUIElement alloc] initWithView:_uiContentView];
    }
    if(!_blendFilter){
        _blendFilter=[[GPUImageAlphaBlendFilter alloc] init];
        _blendFilter.mix = 1.0;
        [_blendFilter disableSecondFrameCheck];
    }
}
/**
 *  停止采集
 */
-(void)stopOutput{
    //关闭界面常亮
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [_camera stopCameraCapture];
    dispatch_async(dispatch_get_main_queue(), ^{
        if(_gpuImageView.superview){
            [_gpuImageView removeFromSuperview];
        }
    });
}
/**
 *  启动采集
 */
-(void)startOuput{
    //保持界面常亮
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    [self configFilter];
    [_camera startCameraCapture];
}
/**
 *  设置预览视图
 *
 *  @param preview 父视图
 */
-(void)setPreview:(UIView *)preview{
    dispatch_async(dispatch_get_main_queue(), ^{
        if(_gpuImageView.superview){
            [_gpuImageView removeFromSuperview];
        }
        [preview insertSubview:_gpuImageView atIndex:0];
        _gpuImageView.frame=preview.bounds;
        _uiContentView.frame=_gpuImageView.bounds;
    });
}
/**
 *  返回预览视图
 *
 */
-(UIView *)preview{
    return _gpuImageView.superview;
}
/**
 *  切换摄像头
 */
-(void)setDevicePosition:(AVCaptureDevicePosition)devicePosition{
    //切换摄像头
    [_camera rotateCamera];
    _camera.frameRate=_videoConfig.frameRate;
}
/**
 *  获取摄像头方向
 */
-(AVCaptureDevicePosition)devicePosition{
    return [_camera cameraPosition];
}
/**
 *  设置方向
 *
 */
-(void)setOrientation:(UIInterfaceOrientation)orientation{
    if(_videoConfig.isLandscape){
        if(orientation==UIInterfaceOrientationLandscapeLeft||orientation==UIInterfaceOrientationLandscapeRight){
            _camera.outputImageOrientation=orientation;
        }else{
            _camera.outputImageOrientation=UIInterfaceOrientationLandscapeLeft;
        }
    }else{
        if(orientation==UIInterfaceOrientationPortrait||orientation==UIInterfaceOrientationPortraitUpsideDown){
            _camera.outputImageOrientation=orientation;
        }else{
            _camera.outputImageOrientation=UIInterfaceOrientationPortrait;
        }
    }
    _orientation=_camera.outputImageOrientation;
}
/**
 *  是否打开闪光灯
 *
 */
-(void)setIsOpenFlash:(BOOL)isOpenFlash{
    if(_camera.captureSession){
        AVCaptureSession *session=_camera.captureSession;
        [session beginConfiguration];
        if(_camera.inputCamera&&_camera.inputCamera.torchAvailable){
            if([_camera.inputCamera lockForConfiguration:nil]){
                [_camera.inputCamera setTorchMode:isOpenFlash?AVCaptureTorchModeOn:AVCaptureTorchModeOff];
                [_camera.inputCamera unlockForConfiguration];
            }
        }
        [session commitConfiguration];
    }

}
/**
 *  闪光灯状态
 */
-(BOOL)isOpenFlash{
    return _camera.inputCamera.torchMode==AVCaptureTorchModeOn;
}
/**
 *  设置mirror
 */
-(void)setMirror:(BOOL)mirror{
    _camera.horizontallyMirrorFrontFacingCamera=mirror;
    _camera.horizontallyMirrorRearFacingCamera=mirror;
    _mirror=mirror;
}
/**
 *  设置缩放
 */
-(void)setVideoZoomScale:(CGFloat)zoomScale andError:(void (^)())errorBlock andfinish:(void (^)())finishBlock{
    if(_camera&&_camera.inputCamera){
        CGFloat maxVideoZoomScale = _camera.inputCamera.activeFormat.videoMaxZoomFactor;
        if (maxVideoZoomScale > 1){
            if([_camera.inputCamera lockForConfiguration:nil]){
                _camera.inputCamera.videoZoomFactor=zoomScale;
                [_camera.inputCamera unlockForConfiguration];
                _zoomScale=zoomScale;
                if(finishBlock){
                    finishBlock();
                }
            }
        }else{
            if(errorBlock){
                errorBlock();
            }
        }
        
    }
}
/**
 *  手动对焦
 *
 *  @param point 焦点位置
 */
-(void)setFocusPoint:(CGPoint)point{
    if (_camera.inputCamera.isFocusPointOfInterestSupported) {
        NSError *error = nil;
        [_camera.inputCamera lockForConfiguration:&error];
        //设置焦点的位置
        if ([_camera.inputCamera isFocusPointOfInterestSupported]) {
            [_camera.inputCamera setFocusPointOfInterest:point];
        }
        
        // 聚焦模式
        if ([_camera.inputCamera isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            [_camera.inputCamera setFocusMode:AVCaptureFocusModeAutoFocus];
        }else{
            NSLog(@"-------------LFCameraDevice：对焦模式修改失败-------------");
        }
        [_camera.inputCamera unlockForConfiguration];
    }
}
/**
 *  设置对焦模式
 *
 *  @param focusMode 对焦模式，默认系统采用系统设备采用的是持续自动对焦模型AVCaptureFocusModeContinuousAutoFocus
 */
-(void)setFocusMode:(AVCaptureFocusMode)focusMode{
    NSError *error = nil;
    [_camera.inputCamera lockForConfiguration:&error];
    // 聚焦模式
    if ([_camera.inputCamera isFocusModeSupported:focusMode]) {
        [_camera.inputCamera setFocusMode:focusMode];
    }else{
        NSLog(@"-------------LFCameraDevice：对焦模式修改失败-------------");
    }
    [_camera.inputCamera unlockForConfiguration];
}
/**
 *  当前摄像头是否支持手动对焦
 */
-(BOOL)isSupportFocusPoint{
    return _camera.inputCamera.isFocusPointOfInterestSupported;
}
/**
 *  滤镜 默认使用美颜效果 可使用GPUImage的定义的滤镜效果，也可基于GPUImage实现自定义滤镜
 */
-(void)setFilterType:(LFCameraDeviceFilter)filterType{
    _filterType=filterType;
    [self configFilter];
}
/**
 *  设置水印
 */
-(void)setLogoView:(UIView *)logoView{
    if(_logoView){
        [_logoView removeFromSuperview];
        _logoView=nil;
    }
    _logoView=logoView;
    _blendFilter.mix=_logoView.alpha;
    [_uiContentView addSubview:_logoView];
    [self configFilter];
}
/**
 *  配置滤镜
 */
- (void)configFilter{
    [_filter removeAllTargets];
    [_blendFilter removeAllTargets];
    [_uiElementInput removeAllTargets];
    [_camera removeAllTargets];
    _output=[[LFOriginalFilter alloc] init];
    switch (_filterType) {
        case LFCameraDeviceFilter_Beautiful:
        {
            _filter=[[LFBeautifulFilter alloc] init];
        }
            break;
        case LFCameraDeviceFilter_Original:
        {
            _filter=[[LFOriginalFilter alloc] init];
        }
            break;
        case LFCameraDeviceFilter_Stretch:
        {
            _filter=[[GPUImageStretchDistortionFilter alloc] init];
        }
            break;
        case LFCameraDeviceFilter_Pinch:
        {
            _filter=[[GPUImagePinchDistortionFilter alloc] init];
        }
            break;
        case LFCameraDeviceFilter_Vignette:
        {
            _filter=[[GPUImageVignetteFilter alloc] init];
            [(GPUImageVignetteFilter *)_filter setVignetteEnd:0.5];
        }
            break;
        default:
        {
            _filter=[[LFBeautifulFilter alloc] init];
        }
            break;
    }
    __weak __typeof(self)weakSelf = self;
    //配置采集数据输出
    [_output setFrameProcessingCompletionBlock:^(GPUImageOutput *imageOutput, CMTime time) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        @autoreleasepool {
            CVPixelBufferRef pixelBufferRef = [imageOutput.framebufferForOutput pixelBuffer];
            if(pixelBufferRef&&strongSelf.delegateFlags.isExistonCameraOutputData){
                [strongSelf.delegate onCameraOutputData:pixelBufferRef];
            }
        }
    }];
    [_camera addTarget:_filter];
    if(_logoView){
        [_filter addTarget:_blendFilter];
        [_uiElementInput addTarget:_blendFilter];
        [_blendFilter addTarget:_gpuImageView];
        [_filter addTarget:_output];
        [_uiElementInput update];
    }else{
        [_filter addTarget:_output];
        [_output addTarget:_gpuImageView];
    }
}
#pragma mark notification handlder
/**
 *  即将进入后台
 */
- (void)willEnterBackground:(NSNotification *)notification {
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [_camera pauseCameraCapture];
    runSynchronouslyOnVideoProcessingQueue(^{
        glFinish();
    });
}
/**
 *  即将回到前台
 */
- (void)willEnterForeground:(NSNotification *)notification {
    [_camera resumeCameraCapture];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}
-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification object:nil];
}
@end
