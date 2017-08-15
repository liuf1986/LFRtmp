//
//  LFCameraDevice.h
//  myrtmp
//
//  Created by liuf on 16/8/3.
// 
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "LFVideoConfig.h"
typedef struct {
    unsigned int isExistonCameraOutputData:1;
} LFCameraDeviceDelegateFlags;

@protocol LFCameraDeviceDelegate <NSObject>
/**
 *  摄像头采集到的数据输出
 */
-(void)onCameraOutputData:(CVImageBufferRef)buffer;

@end
//滤镜常量
typedef enum : char {
    //美颜滤镜
    LFCameraDeviceFilter_Beautiful=1,
    //原始
    LFCameraDeviceFilter_Original=2,
    //拉伸
    LFCameraDeviceFilter_Stretch=3,
    //挤压
    LFCameraDeviceFilter_Pinch=4,
    //管道
    LFCameraDeviceFilter_Vignette=5

    
} LFCameraDeviceFilter;

@interface LFCameraDevice : NSObject
/**
 *  代理
 */
@property (weak,nonatomic) id<LFCameraDeviceDelegate> delegate;
@property (assign,nonatomic) LFCameraDeviceDelegateFlags delegateFlags;
/**
 *  预览页
 */
@property (strong,nonatomic) UIView *preview;
/**
 *  摄像头选取
 */
@property (assign,nonatomic) AVCaptureDevicePosition devicePosition;
/**
 *  方向
 */
@property (assign,nonatomic) UIInterfaceOrientation orientation;
/**
 *  滤镜 默认使用美颜效果 可使用GPUImage的定义的滤镜效果，也可基于GPUImage实现自定义滤镜
 */
@property (assign,nonatomic) LFCameraDeviceFilter filterType;
/**
 *  是否打开闪光灯
 */
@property (assign,nonatomic) BOOL isOpenFlash;
/**
 *  mirror
 */
@property (assign,nonatomic) BOOL mirror;
/**
 *  焦距调整 默认为1.0，可在1.0 ~ 3.0之间调整
 */
@property (assign,nonatomic,readonly) CGFloat zoomScale;
/**
 *  水印
 */
@property (strong,nonatomic) UIView *logoView;
/**
 *  初始化
 *
 *  @param videoConfig 音频采样配置
 */
-(instancetype)init:(LFVideoConfig *)videoConfig;
/**
 *  设置缩放
 */
-(void)setVideoZoomScale:(CGFloat)zoomScale andError:(void (^)())errorBlock andfinish:(void (^)())finishBlock;
/**
 *  手动对焦
 *
 *  @param point 焦点位置
 */
-(void)setFocusPoint:(CGPoint)point;
/**
 *  设置对焦模式
 *
 *  @param focusMode 对焦模式，默认系统采用系统设备采用的是持续自动对焦模型AVCaptureFocusModeContinuousAutoFocus
 */
-(void)setFocusMode:(AVCaptureFocusMode)focusMode;
/**
 *  当前摄像头是否支持手动对焦
 */
-(BOOL)isSupportFocusPoint;
/**
 *  停止采集
 */
-(void)stopOutput;
/**
 *  启动采集
 */
-(void)startOuput;
@end
