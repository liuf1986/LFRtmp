//
//  LFRtmpMessageHeader.m
//  myrtmp
//
//  Created by liuf on 16/7/22.
// 
//
#import "LFRtmpMessageHeader.h"

@implementation LFRtmpMessageHeader
/**
 *  初始化
 *
 *  @param fmtType   basic header中的fmt类型
 *  @param typeID    消息类型
 *  @param streamID  消息流id
 *  @param length    此消息chunk块实际发送数据的大小，这里指LFRtmpChunkData的大小
 *  @param timestamp 时间戳
 *
 *  @return self
 */
-(instancetype)init:(LFRtmpBasicHeaderFmtType)fmtType
             typeID:(LFRtmpMessageType)typeID
           streamID:(uint32_t)streamID
             length:(uint32_t)length
          timestamp:(uint32_t)timestamp{
    self=[super init];
    if(self){
        _fmtType=fmtType;
        _typeID=typeID;
        _streamID=CFSwapInt32HostToLittle(streamID);//转换为小端存储
        _length=length;
        _timestamp=timestamp;
    }
    return self;
}
/**
 *  创建messageHeader的快捷方式
 *
 *  @param fmtType fmt类型
 *  @param data    数据
 *
 *  @return self
 */
+(instancetype)messageHeader:(LFRtmpBasicHeaderFmtType)fmtType data:(NSData *)data{
    switch (fmtType) {
        case LFRtmpBasicHeaderFmtLarge:
        {
            if(data.length!=LFRtmpMessageHeaderSizeLarge){
                NSLog(@"--------------RTMP：调用messageHeader失败，数据不满足格式要求！--------------");
                return nil;
            }
            const uint8_t *bytes=[data bytes];
            uint32_t timestamp=0;
            for(int i=0;i<3;i++){
                timestamp=timestamp|bytes[i];
                if(i!=2){
                    timestamp=timestamp<<8;
                }
            }
            uint32_t length=0;
            for(int i=3;i<6;i++){
                length=length|bytes[i];
                if(i!=5){
                    length=length<<8;
                }
            }
            LFRtmpMessageType msgType=[LFRtmpMessageHeader getMessageType:bytes[6]];
            if(msgType==LFRtmpMessageHeaderTypeUnkonwn){
                NSLog(@"--------------RTMP：调用messageHeader失败，数据不满足格式要求！--------------");
                return nil;
            }
            uint32_t streamId=0;
            for(int i=7;i<11;i++){
                streamId=streamId|bytes[i];
                if(i!=10){
                    streamId=streamId<<8;
                }
            }
            return [[LFRtmpMessageHeader alloc] init:fmtType
                                              typeID:msgType
                                            streamID:streamId
                                              length:length
                                           timestamp:timestamp];
            
        }
            break;
        case LFRtmpBasicHeaderFmtMedium:
        {
            
            if(data.length!=LFRtmpMessageHeaderSizeMedium){
                NSLog(@"--------------RTMP：调用messageHeader失败，数据不满足格式要求！--------------");
                return nil;
            }
            const uint8_t *bytes=[data bytes];
            uint32_t timestamp=0;
            for(int i=0;i<3;i++){
                timestamp=timestamp|bytes[i];
                if(i!=2){
                    timestamp=timestamp<<8;
                }
            }
            uint32_t length=0;
            for(int i=3;i<6;i++){
                length=length|bytes[i];
                if(i!=5){
                    length=length<<8;
                }
            }
            LFRtmpMessageType msgType=[LFRtmpMessageHeader getMessageType:bytes[6]];
            if(msgType==LFRtmpMessageHeaderTypeUnkonwn){
                NSLog(@"--------------RTMP：调用messageHeader失败，数据不满足格式要求！--------------");
                return nil;
            }
            return [[LFRtmpMessageHeader alloc] init:fmtType
                                              typeID:msgType
                                            streamID:0x0
                                              length:length
                                           timestamp:timestamp];
        }
            break;
        case LFRtmpBasicHeaderFmtSmall:
        {
            if(data.length!=LFRtmpMessageHeaderSizeSmall){
                NSLog(@"--------------RTMP：调用messageHeader失败，数据不满足格式要求！--------------");
                return nil;
            }
            const uint8_t *bytes=[data bytes];
            uint32_t timestamp=0;
            for(int i=0;i<3;i++){
                timestamp=timestamp|bytes[i];
                if(i!=2){
                    timestamp=timestamp<<8;
                }
            }
            return [[LFRtmpMessageHeader alloc] init:fmtType
                                              typeID:LFRtmpMessageHeaderTypeUnkonwn
                                            streamID:0x0
                                              length:0x0
                                           timestamp:timestamp];

        }
            break;
        default:
            break;
    }
    NSLog(@"--------------RTMP：调用messageHeader失败，数据不满足格式要求！--------------");
    return nil;
}
/**
 *  返回message header数据
 *
 *  @return 返回message header数据
 */
-(NSData *)data{
    NSMutableData *data=[NSMutableData data];
    uint8_t *bytes=[data mutableBytes];
    switch (_fmtType) {
        case LFRtmpBasicHeaderFmtLarge:
        {
            //type=0时
            //timestamp（时间戳）：占用3个字节
            //message length（消息数据的长度）：占用3个字节,
            //message type id(消息的类型id)：占用1个字节,
            //msg stream id（消息的流id）：占用4个字节
            [data setLength:7];
            //当时间戳的值超最大值时，这三个字节都置为1，并启用扩展时间戳
            if(_timestamp>=kMessageThreeByteMax){
                bytes[0]=0x1;
                bytes[1]=0x1;
                bytes[2]=0x1;
                _extendTimestamp=[[LFRtmpExtendedTimestamp alloc] init:_timestamp];
            }else{
                bytes[0]=_timestamp>>16;
                bytes[1]=_timestamp>>8;
                bytes[2]=_timestamp;
            }
            bytes[3]=_length>>16;
            bytes[4]=_length>>8;
            bytes[5]=_length;
            bytes[6]=_typeID;
            //将4字节的_streamID追加到data尾部总共11字节
            [data appendBytes:&_streamID length:sizeof(_streamID)];
        }
            break;
        case LFRtmpBasicHeaderFmtMedium:
        {
            //type=1时
            //timestamp delta（时间戳）：占用3个字节
            //message length（消息数据的长度）：占用3个字节,
            //message type id(消息的类型id)：占用1个字节,
            [data setLength:LFRtmpMessageHeaderSizeMedium];
            //当时间戳的值超最大值时，这三个字节都置为1，并启用扩展时间戳
            if(_timestamp>=kMessageThreeByteMax){
                bytes[0]=0x1;
                bytes[1]=0x1;
                bytes[2]=0x1;
                _extendTimestamp=[[LFRtmpExtendedTimestamp alloc] init:_timestamp];
            }else{
                bytes[0]=_timestamp>>16;
                bytes[1]=_timestamp>>8;
                bytes[2]=_timestamp;
            }
            bytes[3]=_length>>16;
            bytes[4]=_length>>8;
            bytes[5]=_length;
            bytes[6]=_typeID;
        }
            break;
        case LFRtmpBasicHeaderFmtSmall:
        {
            //type=2时
            //timestamp delta（时间戳）：占用3个字节
            [data setLength:LFRtmpMessageHeaderSizeSmall];
            //当时间戳的值超最大值时，这三个字节都置为1，并启用扩展时间戳
            if(_timestamp>=kMessageThreeByteMax){
                bytes[0]=0x1;
                bytes[1]=0x1;
                bytes[2]=0x1;
                _extendTimestamp=[[LFRtmpExtendedTimestamp alloc] init:_timestamp];
            }else{
                bytes[0]=_timestamp>>16;
                bytes[1]=_timestamp>>8;
                bytes[2]=_timestamp;
            }
        }
            break;
        case LFRtmpBasicHeaderFmtMin:
        {
            NSLog(@"和上一个message header 完全一致！");
        }
            break;
        default:
            break;
    }
    return data;
}

#pragma mark private method
+(LFRtmpMessageType)getMessageType:(uint8_t)msgTypeData{
    LFRtmpMessageType msgType=LFRtmpMessageHeaderTypeUnkonwn;
    switch (msgTypeData) {
        case LFRtmpProControlSetChunkSizeMessage:
        {
            msgType=LFRtmpProControlSetChunkSizeMessage;
        }
            break;
        case LFRtmpProControlAbortMessage:
        {
            msgType=LFRtmpProControlAbortMessage;
        }
            break;
        case LFRtmpProControlAckMessage:
        {
            msgType=LFRtmpProControlAckMessage;
        }
            break;
        case LFRtmpProControlWindowAckSizeMessage:
        {
            msgType=LFRtmpProControlWindowAckSizeMessage;
        }
            break;
        case LFRtmpProControlSetPeerBandWidthMessage:
        {
            msgType=LFRtmpProControlSetPeerBandWidthMessage;
        }
            break;
        case LFRtmpUserControlMessage:
        {
            msgType=LFRtmpUserControlMessage;
        }
            break;
        case LFRtmpAudioMessage:
        {
             msgType=LFRtmpAudioMessage;
        }
            break;
        case LFRtmpVideoMessage:
        {
             msgType=LFRtmpVideoMessage;
        }
            break;
        case LFRtmpDataMessage:
        {
              msgType=LFRtmpDataMessage;
        }
            break;
        case LFRtmpCommandMessage:
        {
            msgType=LFRtmpCommandMessage;
        }
            break;
        default:
            break;
    }
    return msgType;
}
@end
