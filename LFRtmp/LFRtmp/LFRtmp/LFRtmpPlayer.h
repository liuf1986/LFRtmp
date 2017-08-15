//
//  LFRtmpPlayer.h
//  LFRtmp
//
//  Created by liuf on 2017/5/5.
//  Copyright © 2017年 liufang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "LFRtmpUrlParser.h"
typedef enum : NSUInteger {
    LFRTMPPlayStatusConnectionFail,//连接失败
    LFRTMPPlayStatusPlaySending,//发送play指令
    LFRTMPPlayStatusPlayReady,//播放准备就绪
    LFRTMPPlayStatusPlayFail,//发送推送指令失败，不能推流
    LFRTMPPlayStatusPauseSending,//发送pause指令
    LFRTMPPlayStatusPauseSuccess,//pause发送成功
    LFRTMPPlayStatusPauseFail,//pause发送失败
    LFRTMPPlayStatusResumeSending,//发送Resume指令
    LFRTMPPlayStatusResumeSuccess,//Resume发送成功
    LFRTMPPlayStatusResumeFail,//Resume发送失败
    
} LFRTMPPlayStatus;
@protocol LFRtmpPlayDelegate <NSObject>
/**
 *  当rtmp状态发生改变时的回调
 *
 *  @param status 状态描述符
 */
-(void)onRtmpPlayStatusChange:(LFRTMPPlayStatus)status;
@end
@interface LFRtmpPlayer : NSObject

@property (weak,nonatomic) id<LFRtmpPlayDelegate> delegate;
/**
 *  URL地址解析器
 */
@property (strong,nonatomic) LFRtmpUrlParser *urlParser;
/**
 *  初始化
 *
 *  @return self
 */
-(instancetype)initWitPreview:(UIView *)preview;
/**
 *  启动连接
 */
-(void)play;
/**
 *  重新连接
 */
-(void)reStart;
/**
 *  暂停播放
 */
-(void)pause;
/**
 *  继续播放
 */
-(void)resume;

/**
 *  停止播放，重置状态，删除推流 关闭socket连接
 */
-(void)stop;

@end
