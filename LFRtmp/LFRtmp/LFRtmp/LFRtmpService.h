//
//  RtmpService.h
//  myrtmp
//
//  Created by liuf on 16/7/15.
// 
//

#import <Foundation/Foundation.h>
#import "LFAudioConfig.h"
#import "LFVideoConfig.h"
#import <AVFoundation/AVFoundation.h>
#import "LFCameraDevice.h"
#import "LFRtmpUrlParser.h"
typedef enum : NSUInteger {
    LFRTMPStatusConnectionFail,//连接失败
    LFRTMPStatusPublishSending,//发送推流指令
    LFRTMPStatusPublishReady,//发送推送指令成功，可以推流
    LFRTMPStatusPublishFail,//发送推送指令失败，不能推流
    LFRTMPStatusPublishFailBadName //流名错误
} LFRTMPStatus;

@protocol LFRtmpServiceDelegate <NSObject>
/**
 *  当rtmp状态发生改变时的回调
 *
 *  @param status 状态描述符
 */
-(void)onRtmpStatusChange:(LFRTMPStatus)status message:(id)message;
@end

@interface LFRtmpService : NSObject

@property (weak,nonatomic) id<LFRtmpServiceDelegate> delegate;
/**
 *  URL地址解析器
 */
@property (strong,nonatomic) LFRtmpUrlParser *urlParser;
/**
 *  视频采集预览页
 */
@property (strong,nonatomic) UIView *preview;
/**
 *  音频配置信息
 */
@property (strong,nonatomic) LFAudioConfig *audioConfig;
/**
 *  视频配置信息
 */
@property (strong,nonatomic) LFVideoConfig *videoConfig;
/**
 *  方向
 */
@property (assign,nonatomic) UIInterfaceOrientation orientation;

/**
 *  摄像头选取
 */
@property (assign,nonatomic) AVCaptureDevicePosition devicePosition;

/**
 *  是否打开闪光灯
 */
@property (assign,nonatomic) BOOL isOpenFlash;
/**
 *  是否横屏
 */
@property (assign,nonatomic) BOOL isLandscape;
/**
 *  焦距调整
 */
@property (assign,nonatomic,readonly) CGFloat zoomScale;
/**
 *  滤镜 默认使用美颜效果，可使用GPUImage的定义的滤镜效果，也可基于GPUImage实现自定义滤镜
 */
@property (assign,nonatomic) LFCameraDeviceFilter filterType;
/**
 *  水印
 */
@property (strong,nonatomic) UIView *logoView;
+ (id)sharedInstance;
/**
 *  初始化
 *
 *  @param videoConfig 视频配置信息
 *  @param audioConfig 音频配置信息
 *  @param preview 预览页
 *  @return self
 */
-(void)setupWithVideoConfig:(LFVideoConfig *)videoConfig
                audioConfig:(LFAudioConfig *)audioConfig
                    preview:(UIView *)preview;
/**
 *  焦距调整
 */
-(void)setVideoZoomScale:(CGFloat)zoomScale andError:(void (^)())errorBlock;
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
 *  启动连接
 */
-(void)start;
/**
 *  重新连接
 */
-(void)reStart;
/**
 *  停止推流，重置状态，删除推流 关闭socket连接
 */
-(void)stop;
/**
 *  退出，重置状态，删除推流 关闭socket连接，停止采集
 */
-(void)quit;
@end
