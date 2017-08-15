//
//  LFRtmpExtendedTimestamp.m
//  myrtmp
//
//  Created by liuf on 16/7/22.
// 
//

#import "LFRtmpExtendedTimestamp.h"

@implementation LFRtmpExtendedTimestamp
/**
 *  初始化时间戳
 *
 *  @param timestamp 时间戳
 *
 *  @return self
 */
-(instancetype)init:(uint32_t)timestamp{
    self=[super init];
    if(self){
        _timestamp=timestamp;
    }
    return self;
}

/**
 *  快捷方式
 *
 *  @param data 数据
 *
 *  @return self
 */
+(instancetype)extendedTimestamp:(NSData *)data{
    if(data.length!=4){
        NSLog(@"--------------RTMP：调用extendedTimestamp失败，数据不满足格式要求！--------------");
        return nil;
    }
    uint32_t timestamp=0;
    [data getBytes:&timestamp length:4];
    return [[LFRtmpExtendedTimestamp alloc] init:timestamp];
}
/**
 *  数据块
 *
 *  @return data
 */
-(NSData *)data{
    NSData *data=[NSData dataWithBytes:&_timestamp length:sizeof(_timestamp)];
    return data;
}
@end
