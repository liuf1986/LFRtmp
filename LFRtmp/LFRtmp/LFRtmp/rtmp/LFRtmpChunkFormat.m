//
//  RtmpChunFormat.m
//  myrtmp
//
//  Created by liuf on 16/7/22.
//
//

#import "LFRtmpChunkFormat.h"
#import "LFRtmpMessageHeader.h"
#import "LFRtmpResponseCommand.h"

@implementation LFRtmpChunkFormat
{
    LFRtmpBasicHeader *_preBasicHeader;
    LFRtmpMessageHeader *_preMessageHeader;
    dispatch_semaphore_t _semaphore;
    uint64_t _firstTimestamp;
}
-(instancetype)init{
    self=[super init];
    if(self){
        //默认设置为128b
        _inChunkSize=128;
        _outChunkSize=128;
        _semaphore=dispatch_semaphore_create(1);
        _firstTimestamp=0;
    }
    return self;
}
/**
 *  用于RTMP连接的命令数据块
 *
 *  @param appName 例如有推流路径为rtmp://xx.com/userlive/liuf，appName则为userlive
 *  @param tcUrl 例如有推流路径为rtmp://xx.com/userlive/liuf，tcUrl则为rtmp://xx.com/userlive
 *  @return NSData。
 */
-(NSData *)connectChunkFormat:(NSString *)appName tcUrl:(NSString *)tcUrl{
    
    NSMutableData *data=[[NSMutableData alloc] init];
    LFRtmpBasicHeader *basicHeader=[[LFRtmpBasicHeader alloc] init:LFRtmpBasicHeaderFmtLarge
                                                     chunkStreamID:LFRtmpBasicHeaderCommandStreamID
                                                         byteCount:LFRtmpBasicHeaderByteCount1];
    [data appendData:[basicHeader data]];
    NSData *chunkData=[LFRtmpChunkData connectData:appName tcUrl:tcUrl];
    LFRtmpMessageHeader *msgHeader=[[LFRtmpMessageHeader alloc] init:LFRtmpBasicHeaderFmtLarge
                                                              typeID:LFRtmpCommandMessage
                                                            streamID:0x0
                                                              length:(uint32_t)chunkData.length
                                                           timestamp:0x0];
    [data appendData:[msgHeader data]];
    if(msgHeader.extendTimestamp){
        [data appendData:[msgHeader.extendTimestamp data]];
    }
    [data appendData:chunkData];
    return data;
}
/**
 *  用于RTMP释放流的命令数据块
 *
 *  @param streamName 流名
 *
 *  @return NSData
 */
-(NSData *)releaseStreamChunkFormat:(NSString *)streamName{
    NSMutableData *data=[[NSMutableData alloc] init];
    LFRtmpBasicHeader *basicHeader=[[LFRtmpBasicHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                     chunkStreamID:LFRtmpBasicHeaderCommandStreamID
                                                         byteCount:LFRtmpBasicHeaderByteCount1];
    [data appendData:[basicHeader data]];
    NSData *chunkData=[LFRtmpChunkData releaseStreamData:streamName];
    LFRtmpMessageHeader *msgHeader=[[LFRtmpMessageHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                              typeID:LFRtmpCommandMessage
                                                            streamID:0x0
                                                              length:(uint32_t)chunkData.length
                                                           timestamp:0x0];
    [data appendData:[msgHeader data]];
    if(msgHeader.extendTimestamp){
        [data appendData:[msgHeader.extendTimestamp data]];
    }
    [data appendData:chunkData];
    return data;
}
/**
 *  用于RTMP fcPublish的命令数据块
 *
 *  @param streamName 流名
 *
 *  @return NSData
 */
-(NSData *)fcPublishStreamChunkFormat:(NSString *)streamName{
    NSMutableData *data=[[NSMutableData alloc] init];
    LFRtmpBasicHeader *basicHeader=[[LFRtmpBasicHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                     chunkStreamID:LFRtmpBasicHeaderCommandStreamID
                                                         byteCount:LFRtmpBasicHeaderByteCount1];
    [data appendData:[basicHeader data]];
    NSData *chunkData=[LFRtmpChunkData fcPublishData:streamName];
    LFRtmpMessageHeader *msgHeader=[[LFRtmpMessageHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                              typeID:LFRtmpCommandMessage
                                                            streamID:0x0
                                                              length:(uint32_t)chunkData.length
                                                           timestamp:0x0];
    [data appendData:[msgHeader data]];
    if(msgHeader.extendTimestamp){
        [data appendData:[msgHeader.extendTimestamp data]];
    }
    [data appendData:chunkData];
    return data;
}
/**
 *  用于RTMP createStream的命令数据块
 *
 *  @return NSData
 */
-(NSArray *)createStreamChunkForamt{
    NSMutableData *data=[[NSMutableData alloc] init];
    LFRtmpBasicHeader *basicHeader=[[LFRtmpBasicHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                     chunkStreamID:LFRtmpBasicHeaderCommandStreamID
                                                         byteCount:LFRtmpBasicHeaderByteCount1];
    [data appendData:[basicHeader data]];
    NSArray *createArray=[LFRtmpChunkData createStreamData];
    NSData *chunkData=[createArray firstObject];
    LFRtmpMessageHeader *msgHeader=[[LFRtmpMessageHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                              typeID:LFRtmpCommandMessage
                                                            streamID:0x0
                                                              length:(uint32_t)chunkData.length
                                                           timestamp:0x0];
    [data appendData:[msgHeader data]];
    if(msgHeader.extendTimestamp){
        [data appendData:[msgHeader.extendTimestamp data]];
    }
    [data appendData:chunkData];
    NSMutableArray *array=[NSMutableArray new];
    [array addObject:data];
    [array addObject:[createArray lastObject]];
    return array;
}
/**
 *  用于RTMP checkbw的命令数据块
 *
 *  @return NSData
 */
-(NSData *)checkbwChunkForamt{
    NSMutableData *data=[[NSMutableData alloc] init];
    LFRtmpBasicHeader *basicHeader=[[LFRtmpBasicHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                     chunkStreamID:LFRtmpBasicHeaderCommandStreamID
                                                         byteCount:LFRtmpBasicHeaderByteCount1];
    [data appendData:[basicHeader data]];
    NSData *chunkData=[LFRtmpChunkData checkbwData];
    LFRtmpMessageHeader *msgHeader=[[LFRtmpMessageHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                              typeID:LFRtmpCommandMessage
                                                            streamID:0x0
                                                              length:(uint32_t)chunkData.length
                                                           timestamp:0x0];
    [data appendData:[msgHeader data]];
    if(msgHeader.extendTimestamp){
        [data appendData:[msgHeader.extendTimestamp data]];
    }
    [data appendData:chunkData];
    return data;
}
/**
 *  用于RTMP deleteStream的命令数据块
 *
 *  @return NSData
 */
-(NSData *)deleteStreamForamt:(int)streamID{
    NSMutableData *data=[[NSMutableData alloc] init];
    LFRtmpBasicHeader *basicHeader=[[LFRtmpBasicHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                     chunkStreamID:LFRtmpBasicHeaderCommandStreamID
                                                         byteCount:LFRtmpBasicHeaderByteCount1];
    [data appendData:[basicHeader data]];
    NSData *chunkData=[LFRtmpChunkData deleteStreamData:streamID];
    LFRtmpMessageHeader *msgHeader=[[LFRtmpMessageHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                              typeID:LFRtmpCommandMessage
                                                            streamID:0x0
                                                              length:(uint32_t)chunkData.length
                                                           timestamp:0x0];
    [data appendData:[msgHeader data]];
    if(msgHeader.extendTimestamp){
        [data appendData:[msgHeader.extendTimestamp data]];
    }
    [data appendData:chunkData];
    return data;
}
/**
 *  用于RTMP publish的命令数据块
 *
 *  @param streamName 流名
 *
 *  @return NSData
 */
-(NSData *)publishStreamChunkFormat:(NSString *)streamName{
    NSMutableData *data=[[NSMutableData alloc] init];
    LFRtmpBasicHeader *basicHeader=[[LFRtmpBasicHeader alloc] init:LFRtmpBasicHeaderFmtLarge
                                                     chunkStreamID:LFRtmpBasicHeaderMediaStreamID
                                                         byteCount:LFRtmpBasicHeaderByteCount1];
    [data appendData:[basicHeader data]];
    NSData *chunkData=[LFRtmpChunkData publishData:streamName];
    LFRtmpMessageHeader *msgHeader=[[LFRtmpMessageHeader alloc] init:LFRtmpBasicHeaderFmtLarge
                                                              typeID:LFRtmpCommandMessage
                                                            streamID:0x1
                                                              length:(uint32_t)chunkData.length
                                                           timestamp:0x0];
    [data appendData:[msgHeader data]];
    if(msgHeader.extendTimestamp){
        [data appendData:[msgHeader.extendTimestamp data]];
    }
    [data appendData:chunkData];
    return data;
}
/**
 *  用于RTMP fcunpublish的命令数据块
 *
 *  @param streamName 流名
 *
 *  @return NSData
 */
-(NSData *)fcUnPublishStreamChunkFormat:(NSString *)streamName{
    NSMutableData *data=[[NSMutableData alloc] init];
    LFRtmpBasicHeader *basicHeader=[[LFRtmpBasicHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                     chunkStreamID:LFRtmpBasicHeaderCommandStreamID
                                                         byteCount:LFRtmpBasicHeaderByteCount1];
    [data appendData:[basicHeader data]];
    NSData *chunkData=[LFRtmpChunkData fcunPublishData:streamName];
    LFRtmpMessageHeader *msgHeader=[[LFRtmpMessageHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                              typeID:LFRtmpCommandMessage
                                                            streamID:0x0
                                                              length:(uint32_t)chunkData.length
                                                           timestamp:0x0];
    [data appendData:[msgHeader data]];
    if(msgHeader.extendTimestamp){
        [data appendData:[msgHeader.extendTimestamp data]];
    }
    [data appendData:chunkData];
    return data;
}
/**
 *  用于拼装RTMP setDataFrame命令的AMF0数据结构,用于设置元数据metadata，音视频参数
 *
 *  @param videoConfig 视频信息
 *  @param audioConfig 音频信息
 *  @return NSData
 */
-(NSData *)setDataFrameChunkFormat:(LFVideoConfig *)videoConfig
                       audioConfig:(LFAudioConfig *)audioConfig{
    NSMutableData *data=[[NSMutableData alloc] init];
    LFRtmpBasicHeader *basicHeader=[[LFRtmpBasicHeader alloc] init:LFRtmpBasicHeaderFmtLarge
                                                     chunkStreamID:LFRtmpBasicHeaderMediaStreamID
                                                         byteCount:LFRtmpBasicHeaderByteCount1];
    [data appendData:[basicHeader data]];
    NSData *chunkData=[LFRtmpChunkData setDataFrameData:videoConfig audioConfig:audioConfig];
    LFRtmpMessageHeader *msgHeader=[[LFRtmpMessageHeader alloc] init:LFRtmpBasicHeaderFmtLarge
                                                              typeID:LFRtmpDataMessage
                                                            streamID:0x1
                                                              length:(uint32_t)chunkData.length
                                                           timestamp:0x0];
    [data appendData:[msgHeader data]];
    if(msgHeader.extendTimestamp){
        [data appendData:[msgHeader.extendTimestamp data]];
    }
    [data appendData:chunkData];
    return data;
}
/**
 *  FLV AAC音频同步包。 不论向 RTMP 服务器推送音频还是视频，都需要按照 FLV 的格式进行封包。因此，在我们向服务器推送第一个 AAC包之前，
 *  需要首先推送一个音频 Tag [AAC Sequence Header].
 *  具体内容见FLV官方文档AAC Sequence Header章节
 *  @return NSData
 */
-(NSMutableData *)flvAACSequenceHeader{
    NSMutableData *data=[[NSMutableData alloc] init];
    LFRtmpBasicHeader *basicHeader=[[LFRtmpBasicHeader alloc] init:LFRtmpBasicHeaderFmtLarge
                                                     chunkStreamID:LFRtmpBasicHeaderMediaStreamID
                                                         byteCount:LFRtmpBasicHeaderByteCount1];
    [data appendData:[basicHeader data]];
    NSData *chunkData=[LFRtmpChunkData flvAACSequenceHeader];
    LFRtmpMessageHeader *msgHeader=[[LFRtmpMessageHeader alloc] init:LFRtmpBasicHeaderFmtLarge
                                                              typeID:LFRtmpAudioMessage
                                                            streamID:0x1
                                                              length:(uint32_t)chunkData.length
                                                           timestamp:0x0];
    [data appendData:[msgHeader data]];
    if(msgHeader.extendTimestamp){
        [data appendData:[msgHeader.extendTimestamp data]];
    }
    [data appendData:chunkData];
    return data;
}
/**
 *  使用FLV封装AAC格式的音频包
 *
 *  @param encodeData AAC格式的音频数据
 *
 *  @return NSData
 */
-(NSMutableData *)flvAACAudioData:(NSData *)encodeData{
    NSMutableData *data=[[NSMutableData alloc] init];
    LFRtmpBasicHeader *basicHeader=[[LFRtmpBasicHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                     chunkStreamID:LFRtmpBasicHeaderMediaStreamID
                                                         byteCount:LFRtmpBasicHeaderByteCount1];
    [data appendData:[basicHeader data]];
    NSData *chunkData=[LFRtmpChunkData flvAACAudioData:encodeData];
    LFRtmpMessageHeader *msgHeader=[[LFRtmpMessageHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                              typeID:LFRtmpAudioMessage
                                                            streamID:0x0
                                                              length:(uint32_t)chunkData.length
                                                           timestamp:[self currentTimestamp]];
    [data appendData:[msgHeader data]];
    if(msgHeader.extendTimestamp){
        [data appendData:[msgHeader.extendTimestamp data]];
    }
    [data appendData:chunkData];
    return data;
}
/**
 *  FLV 视频频同步包
 */
-(NSData *)flvVideoSequenceHeader:(LFVideoEncodeInfo *)info{
    NSMutableData *data=[[NSMutableData alloc] init];
    LFRtmpBasicHeader *basicHeader=[[LFRtmpBasicHeader alloc] init:LFRtmpBasicHeaderFmtLarge
                                                     chunkStreamID:LFRtmpBasicHeaderMediaStreamID
                                                         byteCount:LFRtmpBasicHeaderByteCount1];
    [data appendData:[basicHeader data]];
    NSData *chunkData=[LFRtmpChunkData flvVideoSequenceHeader:info];
    LFRtmpMessageHeader *msgHeader=[[LFRtmpMessageHeader alloc] init:LFRtmpBasicHeaderFmtLarge
                                                              typeID:LFRtmpVideoMessage
                                                            streamID:0x1
                                                              length:(uint32_t)chunkData.length
                                                           timestamp:info.timeStamp];
    [data appendData:[msgHeader data]];
    if(msgHeader.extendTimestamp){
        [data appendData:[msgHeader.extendTimestamp data]];
    }
    [data appendData:chunkData];
    return data;
}
/**
 *  使用FLV封装h264格式的视频包
 *
 *  @param encodeData h264格式的视频数据
 *
 *  @return NSData
 */
-(NSData *)flvVideoData:(LFVideoEncodeInfo *)info{
    NSMutableData *data=[[NSMutableData alloc] init];
    LFRtmpBasicHeader *basicHeader=[[LFRtmpBasicHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                     chunkStreamID:LFRtmpBasicHeaderMediaStreamID
                                                         byteCount:LFRtmpBasicHeaderByteCount1];
    [data appendData:[basicHeader data]];
    NSData *chunkData=[LFRtmpChunkData flvVideoData:info];
    LFRtmpMessageHeader *msgHeader=[[LFRtmpMessageHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                              typeID:LFRtmpVideoMessage
                                                            streamID:0x0
                                                              length:(uint32_t)chunkData.length
                                                           timestamp:info.timeStamp];
    [data appendData:[msgHeader data]];
    if(msgHeader.extendTimestamp){
        [data appendData:[msgHeader.extendTimestamp data]];
    }
    [data appendData:chunkData];
    return data;
}
/**
 *  用于拼装RTMP getStreamLength命令的AMF0数据结构
 *
 *  @param streamName 流名
 *  @return NSData
 */
-(NSData *)getStreamLengthChunkFormat:(NSString *)streamName{
    NSMutableData *data=[[NSMutableData alloc] init];
    LFRtmpBasicHeader *basicHeader=[[LFRtmpBasicHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                     chunkStreamID:LFRtmpBasicHeaderCommandStreamID
                                                         byteCount:LFRtmpBasicHeaderByteCount1];
    [data appendData:[basicHeader data]];
    NSData *chunkData=[LFRtmpChunkData getStreamLengthData:streamName];
    LFRtmpMessageHeader *msgHeader=[[LFRtmpMessageHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                              typeID:LFRtmpCommandMessage
                                                            streamID:0x0
                                                              length:(uint32_t)chunkData.length
                                                           timestamp:0x0];
    [data appendData:[msgHeader data]];
    if(msgHeader.extendTimestamp){
        [data appendData:[msgHeader.extendTimestamp data]];
    }
    [data appendData:chunkData];
    return data;
}
/**
 *  用于拼装RTMP play命令的AMF0数据结构
 *
 *  @param streamName 流名
 *  @return NSData
 */
-(NSData *)playChunkFormat:(NSString *)streamName{
    NSMutableData *data=[[NSMutableData alloc] init];
    LFRtmpBasicHeader *basicHeader=[[LFRtmpBasicHeader alloc] init:LFRtmpBasicHeaderFmtLarge
                                                     chunkStreamID:LFRtmpBasicHeaderCommandStreamID
                                                         byteCount:LFRtmpBasicHeaderByteCount1];
    [data appendData:[basicHeader data]];
    NSData *chunkData=[LFRtmpChunkData playData:streamName];
    LFRtmpMessageHeader *msgHeader=[[LFRtmpMessageHeader alloc] init:LFRtmpBasicHeaderFmtLarge
                                                              typeID:LFRtmpCommandMessage
                                                            streamID:0x1
                                                              length:(uint32_t)chunkData.length
                                                           timestamp:0x0];
    [data appendData:[msgHeader data]];
    if(msgHeader.extendTimestamp){
        [data appendData:[msgHeader.extendTimestamp data]];
    }
    [data appendData:chunkData];
    return data;
}
/**
 *  用于拼装RTMP 用户控制事件的setBufferLength，这个事件在服务器开始处理流数据前发送。类型为3，事件数据的前 4 字节表示流 ID,接下来的4 字节表示缓冲区的大小(单位是毫秒)。
 *
 *  @param streamid 流ID
 *  @param  buffersize 缓冲区大小
 *  @return NSData
 */
-(NSData *)setBufferLengthChunkFormat:(uint32_t)streamId bufferSize:(uint32_t)bufferSize{
    NSMutableData *data=[[NSMutableData alloc] init];
    LFRtmpBasicHeader *basicHeader=[[LFRtmpBasicHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                     chunkStreamID:LFRtmpBasicHeaderProControlStreamID
                                                         byteCount:LFRtmpBasicHeaderByteCount1];
    [data appendData:[basicHeader data]];
    NSData *chunkData=[LFRtmpChunkData setBufferLengthData:streamId bufferSize:bufferSize];
    LFRtmpMessageHeader *msgHeader=[[LFRtmpMessageHeader alloc] init:LFRtmpBasicHeaderFmtMedium
                                                              typeID:LFRtmpUserControlMessage
                                                            streamID:0x0
                                                              length:(uint32_t)chunkData.length
                                                           timestamp:0x0];
    [data appendData:[msgHeader data]];
    if(msgHeader.extendTimestamp){
        [data appendData:[msgHeader.extendTimestamp data]];
    }
    [data appendData:chunkData];
    return data;
}
/**
 *  用于拼装RTMP pause命令的AMF0数据结构
 *
 *  @param isFlag 暂停流还是继续
 *  @param milliSeconds 流暂停或者继续播放的毫秒数
 
 *  @return NSData
 */
-(NSData *)pauseChunkFormat:(BOOL)isFlag milliSeconds:(int)milliSeconds{
    NSMutableData *data=[[NSMutableData alloc] init];
    LFRtmpBasicHeader *basicHeader=[[LFRtmpBasicHeader alloc] init:LFRtmpBasicHeaderFmtLarge
                                                     chunkStreamID:LFRtmpBasicHeaderCommandStreamID
                                                         byteCount:LFRtmpBasicHeaderByteCount1];
    [data appendData:[basicHeader data]];
    NSData *chunkData=[LFRtmpChunkData pauseData:isFlag milliSeconds:milliSeconds];
    LFRtmpMessageHeader *msgHeader=[[LFRtmpMessageHeader alloc] init:LFRtmpBasicHeaderFmtLarge
                                                              typeID:LFRtmpCommandMessage
                                                            streamID:0x1
                                                              length:(uint32_t)chunkData.length
                                                           timestamp:0x0];
    [data appendData:[msgHeader data]];
    if(msgHeader.extendTimestamp){
        [data appendData:[msgHeader.extendTimestamp data]];
    }
    [data appendData:chunkData];
    return data;
}
/**
 如果一个包的大小超过chunk size的大小 则需要添加包分隔符，包分隔符的规则为0xc0|chunk stream ID
 例如如果是协议控制块流则chunk stream ID为0x2，包分隔符=0xc0|0x2=0xc2
 每两个分隔符之前的数据量是chunk size 的大小，而在整个数据包中分隔符的下标位置的规律
 为chunk size，(chunk size)*2+1，(chunk size)*3+2 。。。这个规律

 *
 *  @param chunkStreamID 块流ID
 *
 *  @return 包分隔符
 */
+(uint8_t)chunkPacketSplitChar:(LFRtmpBasicHeaderChunkStreamID)chunkStreamID{
    return 0xc0|chunkStreamID;
}

/**
 *  当前时间戳
 *
 *  @return uint32_t
 */
-(uint32_t)currentTimestamp{
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    uint32_t current=0;
    if(_firstTimestamp==0){
        _firstTimestamp=[[NSDate date] timeIntervalSince1970]*1000;
    }else{
        current=[[NSDate date] timeIntervalSince1970]*1000-_firstTimestamp;
        _firstTimestamp=current+_firstTimestamp;
    }
    dispatch_semaphore_signal(_semaphore);
    return current;
}
@end
