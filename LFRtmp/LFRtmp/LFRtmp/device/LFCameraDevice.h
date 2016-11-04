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
 *  是否启用面部识别功能
 */
@property (assign,nonatomic) BOOL isEnableFace;
/**
 *  mirror
 */
@property (assign,nonatomic) BOOL mirror;
/**
 *  焦距调整 默认为1.0，可在1.0 ~ 3.0之间调整
 */
@property (assign,nonatomic) CGFloat zoomScale;
/**
 *  水印
 */
@property (strong,nonatomic) UIView *logoView;

/**
 *  贴纸
 */
@property (strong,nonatomic) UIView *faceView;
/**
 *  初始化
 *
 *  @param videoConfig 音频采样配置
 */
-(instancetype)init:(LFVideoConfig *)videoConfig;
/**
 *  停止采集
 */
-(void)stopOutput;
/**
 *  启动采集
 */
-(void)startOuput;
@end
