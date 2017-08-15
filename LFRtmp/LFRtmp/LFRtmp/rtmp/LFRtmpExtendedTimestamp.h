//
//  LFRtmpExtendedTimestamp.h
//  myrtmp
//
//  Created by liuf on 16/7/22.
// 
//
/**
 *   在chunk中会有时间戳timestamp和时间戳差timestamp delta，并且它们不会同时存在，只有这两者之一大于3个字节能表示的最大数值0xFFFFFF＝16777215时，才会用这个字段来表示真正的时间戳，否则这个字段为0。扩展时间戳占4个字节，能表示的最大数值就是0xFFFFFFFF＝4294967295。当扩展时间戳启用时，timestamp字段或者timestamp delta要全置为1，表示应该去扩展时间戳字段来提取真正的时间戳或者时间戳差。注意扩展时间戳存储的是完整值，而不是减去时间戳或者时间戳差的值。
 */
#import <Foundation/Foundation.h>

@interface LFRtmpExtendedTimestamp : NSObject
@property (assign,nonatomic,readonly) uint32_t timestamp;
/**
 *  初始化时间戳
 *
 *  @param timestamp 时间戳
 *
 *  @return self
 */
-(instancetype)init:(uint32_t)timestamp;
/**
 *  快捷方式
 *
 *  @param data 数据
 *
 *  @return self
 */
+(instancetype)extendedTimestamp:(NSData *)data;
/**
 *  数据块
 *
 *  @return data
 */
-(NSData *)data;
@end
