//
//  LFRTMPReadBuffer.m
//  LFRtmp
//
//  Created by liuf on 2017/5/8.
//  Copyright © 2017年 liufang. All rights reserved.
//
#import "LFRTMPReadBuffer.h"
@implementation LFRTMPReadBuffer
{
    NSMutableData *_data;
}
-(instancetype)init{
    if(self=[super init]){
        _expectedSize=1;
        _data=[NSMutableData new];
    }
    return self;
}
/**
 *  追加数据
 */
-(void)appendData:(NSData *)data{
    [_data appendData:data];
}

-(int)size{
    return (int)_data.length;
}
/**
 *  获取知道长度的数据
 *
 *  @param expectedSize 预计要取的数据长度
 */
-(NSData *)getExpectedBuffer:(int)expectedSize{
    if(_data.length>=expectedSize){
        __weak NSData *data= [_data subdataWithRange:NSMakeRange(0, expectedSize)];
        [_data replaceBytesInRange:NSMakeRange(0, expectedSize) withBytes:NULL length:0];
        return data;
    }else{
        return nil;
    }
}
@end
