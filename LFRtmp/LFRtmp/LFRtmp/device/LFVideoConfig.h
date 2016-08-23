//
//  LFVideoConfig.h
//  myrtmp
//
//  Created by liuf on 16/8/4.
// 
//
/**
 *  视频配置信息
 */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
//适配分辨率等级
typedef enum : int {
    //低分辨率
    LFVideoConfigResolution360_640=1,
    //中分辨率
    LFVideoConfigResolution540_960=2,
    //高分辨率
    LFVideoConfigResolution720_1280=3,

} LFVideoConfigResolution;

//视频质量
typedef enum : char {
    //分辨率360x640 帧率 15 码率 500kbps
    LFVideoConfigQuality_Low1=1,
    //分辨率360x640 帧率 24 码率 600kbps
    LFVideoConfigQuality_Low2=2,
    //分辨率360x640 帧率 30 码率 800kbps
    LFVideoConfigQuality_Low3=3,
    //分辨率540x960 帧率 15 码率 800kbps
    LFVideoConfigQuality_Middle1=4,
    //分辨率540x960 帧率 24 码率 800kbps
    LFVideoConfigQuality_Middle2=5,
    //分辨率540x960 帧率 30 码率 800kbps
    LFVideoConfigQuality_Middle3=6,
    //分辨率720x1280 帧率 15 码率 1000kbps
    LFVideoConfigQuality_Hight1=7,
    //分辨率720x1280 帧率 24 码率 1200kbps
    LFVideoConfigQuality_Hight2=8,
    //分辨率720x1280 帧率 30 码率 1200kbps
    LFVideoConfigQuality_Hight3=10,
    LFVideoConfigQuality_Default=LFVideoConfigQuality_Low2

} LFVideoConfigQuality;

@interface LFVideoConfig : NSObject

/**
 *  通过默认配置实例化
 *
 *  @return self
 */
+(instancetype)defaultConfig;

/**
 *  通过LFVideoConfigQuality初始化
 *
 *  @param quality 视频质量
 *  @param isLandscape 是否横屏
 *  @return self
 */
-(instancetype)init:(LFVideoConfigQuality)quality isLandscape:(BOOL)isLandscape;
/**
 *  视频采集分辨率的组合
 */
@property (assign,nonatomic,readonly) CGSize videoSize;
/**
 *  是否横屏
 */
@property (assign,nonatomic,readonly) BOOL isLandscape;
/**
 *  帧率
 */
@property (assign,nonatomic,readonly) int frameRate;
/**
 *  最大帧率
 */
@property (assign,nonatomic,readonly) int maxFrameRate;
/**
 *  最小帧率
 */
@property (assign,nonatomic,readonly) int minFrameRate;
/**
 *  最大关键帧间隔，为frameRate的两倍
 */
@property (assign,nonatomic,readonly) NSUInteger maxKeyframeInterval;
/**
 *  码率
 */
@property (assign,nonatomic,readonly) int bitRate;
/**
 *  最大码率
 */
@property (assign,nonatomic,readonly) int maxBitRate;
/**
 *  最小码率
 */
@property (assign,nonatomic,readonly) int minBitRate;
/**
 *  分辨率等级
 */
@property (assign,nonatomic,readonly) LFVideoConfigResolution resolution;
/**
 *  AVFoundtion视频采集时的分辨率常量
 */
@property (assign,nonatomic,readonly) NSString  *videoSessionPreset;
@end
