//
//  LFRTMPReadBuffer.h
//  LFRtmp
//
//  Created by liuf on 2017/5/8.
//  Copyright © 2017年 liufang. All rights reserved.
//

#import <Foundation/Foundation.h>
@interface LFRTMPReadBuffer : NSObject
@property (nonatomic,assign)int expectedSize;//预计读取的大小,如果给定值则需读取到指定大小的数据，如果是0则不限制
/**
 *  已存数据长度
 */
-(int)size;
/**
 *  追加数据
 */
-(void)appendData:(NSData *)data;

/**
 *  获取知道长度的数据
 *
 *  @param expectedSize 预计要取的数据长度
 */
-(NSData *)getExpectedBuffer:(int)expectedSize;
@end
