//
//  LFVideoEncodeInterface.h
//  myrtmp
//
//  Created by liuf on 16/8/12.
// 
//

#import <Foundation/Foundation.h>
#import "LFVideoConfig.h"
#import <AVFoundation/AVFoundation.h>
#import "LFVideoEncodeInfo.h"
@protocol LFVideoEncodeDelegate <NSObject>

-(void)onDidVideoEncodeOutput:(LFVideoEncodeInfo *)info;

@end

@protocol LFVideoEncodeProtocol <NSObject>
@required
/**
 *  初始化
 */
-(instancetype)init:(LFVideoConfig *)videoConfig;
/**
 *  h264编码
 */
-(void)encode:(CVImageBufferRef)buffer timeStamp:(uint64_t)timeStamp;
/**
 *  编码数据输出代理
 */
-(void)setDelegate:(id<LFVideoEncodeDelegate>)delegate;
/**
 *  停止编码
 */
- (void)stopEncode;
@end



