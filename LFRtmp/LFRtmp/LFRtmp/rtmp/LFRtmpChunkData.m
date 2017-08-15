//
//  LFRtmpChunkData.m
//  myrtmp
//
//  Created by liuf on 16/7/22.
//
//

#import "LFRtmpChunkData.h"
#import "AMFArchiver.h"
#import "DevicePlatform.h"
static int sendTransactionID=0;
@implementation LFRtmpChunkData
/**
 *  初始化
 *
 *  @param data        用于初始化的二进制数据
 *  @param messageType 数据的种类
 *
 *  @return self
 */
-(instancetype)init:(NSData *)data{
    self=[super init];
    if(self){
        _data=data;
    }
    return self;
}
/**
 *  处理协议控制消息 Set Chunk Size
 *
 *  @return chunk size大小
 */
-(uint32_t)parseSetChunkSize{
    if(_data.length==4){
        uint32_t size=0;
        const uint8_t *bytes=[_data bytes];
        for(int i=0;i<4;i++){
            size=size|bytes[i];
            if(i!=3){
                size=size<<8;
            }
        }
        return size;
    }else{
        NSLog(@"--------------RTMP：调用parseSetChunkSize失败，数据不满足格式要求！--------------");
        return 0x0;
    }
}
/**
 *  处理协议控制消息 Abort Message
 *
 *  @return 块流 ID，用来通知对端如果正在等待接收消息的块那么就丢弃已通过块流接收到的消息
 */
-(uint32_t)parseAbortMessage{
    if(_data.length==4){
        uint32_t streamID=0;
        const uint8_t *bytes=[_data bytes];
        for(int i=0;i<4;i++){
            streamID=streamID|bytes[i];
            if(i!=3){
                streamID=streamID<<8;
            }
        }
        return streamID;
    }else{
        NSLog(@"--------------RTMP：调用parseAbortMessage失败，数据不满足格式要求！--------------");
        return 0x0;
    }
}
/**
 *  处理协议控制消息 Acknowledgement
 *
 *  @return 序列号(sequence number,32 位):这个字段包含了目前为止接收到的字节数
 */
-(uint32_t)parseAcknowledgement{
    if(_data.length==4){
        uint32_t seqNum=0;
        const uint8_t *bytes=[_data bytes];
        for(int i=0;i<4;i++){
            seqNum=seqNum|bytes[i];
            if(i!=3){
                seqNum=seqNum<<8;
            }
        }
        return seqNum;
    }else{
        NSLog(@"--------------RTMP：调用parseAcknowledgement失败，数据不满足格式要求！--------------");
        return 0x0;
    }
}
/**
 *  处理协议控制消息 Windows Acknowledgement Size
 *
 *  @return 窗口确认大小
 */
-(uint32_t)parseWindowAckSize{
    if(_data.length==4){
        uint32_t size=0;
        const uint8_t *bytes=[_data bytes];
        for(int i=0;i<4;i++){
            size=size|bytes[i];
            if(i!=3){
                size=size<<8;
            }
        }
        return size;
    }else{
        NSLog(@"--------------RTMP：调用parseWindowAckSize失败，数据不满足格式要求！--------------");
        return 0x0;
    }
}
/**
 *  处理协议控制消息 Set Peer Bandwidth
 *
 *  @return 设置对端带宽大小
 */
-(NSDictionary *)parseBandWidth{
    if(_data.length==5){
        const uint8_t *bytes=[_data bytes];
        uint32_t size=0;
        for(int i=0;i<4;i++){
            size=size|bytes[i];
            if(i!=3){
                size=size<<8;
            }
        }
        uint8_t type=bytes[4];
        NSMutableDictionary *dic=[NSMutableDictionary new];
        [dic setValue:[NSNumber numberWithLong:size] forKey:kBandWidthSize];
        [dic setValue:[NSNumber numberWithChar:type] forKey:kBandWidthLimitType];
        return dic;
    }else{
        NSLog(@"--------------RTMP：调用parseBandWidth失败，数据不满足格式要求！--------------");
        return nil;
    }
}
/**
 *  处理用户控制消息，对应推流端不需要处理其他的用户控制消息
 *  @return 服务器告诉客户端流是否已就绪用于通讯
 */
-(BOOL)parseUserCtrlStreamBegin{
    if(_data.length==6){
        const uint8_t *bytes=[_data bytes];
        uint16_t eventType=0;
        //用户控制消息的格式为前两个字节为类型，后4个字节为附带数据
        eventType=eventType|bytes[0];
        eventType=eventType<<8;
        eventType=eventType|bytes[1];
        if(eventType==0){
            return YES;
        }else{
//            NSLog(@"--------------RTMP：调用parseUserCtrlStreamBegin失败，这不是Stream Begin Event！--------------");
            return NO;
        }
    }else{
        NSLog(@"--------------RTMP：调用parseUserCtrlStreamBegin失败，数据不满足格式要求！--------------");
        return NO;
    }
}
/**
 *  处理命令消息body
 *
 *  @return LFRtmpCommand
 */
-(LFRtmpResponseCommand *)parseCommand{
    LFRtmpResponseCommand *command=nil;
    //如果是命令消息则判断首字节是否是0x2,因为命令消息的前部都是以字符串表示命令名称
    //而在AMF0中字符串类型是0x2
    if(_data.length>0){
        const uint8_t *bytes=[_data bytes];
        uint8_t byte=bytes[0];
        if(byte!=0x2){
            NSLog(@"--------------RTMP：调用parseCommand失败，命令消息的首字节必须为0x2！--------------");
        }else{
            command=[[LFRtmpResponseCommand alloc] init:_data];
        }
    }
    return command;
}

#pragma mark handle method
/**
 *  用于拼装RTMP连接命令的数据结构
 *
 *  @param appName 例如有推流路径为rtmp://xx.com/userlive/liuf，appName则为userlive
 *  @param tcUrl 例如有推流路径为rtmp://xx.com/userlive/liuf，tcUrl则为rtmp://xx.com/userlive
 *  @return 返回拼装好的数据块。
 */
+(NSData *)connectData:(NSString *)appName tcUrl:(NSString *)tcUrl{
    AMFArchiver *archiver=[[AMFArchiver alloc] initForWritingWithMutableData:[NSMutableData data]
                                                                    encoding:kAMF0Encoding];
    /**
     * connect命令结构
     | Field Name | Type | Description |
     |命令名称 | String | 命令的名称. 设置成 "connect"
     |事务ID |Number| int |
     |命令对象 | Object | 键值对的命令信息 |
     |可选用户参数 | Object | 任意可选的信息 |
     */
    [archiver encodeObject:@"connect"];//命令名称
    [archiver encodeObject:[NSNumber numberWithInt:++sendTransactionID]];
    NSMutableDictionary *dic=[NSMutableDictionary new];
    [dic setValue:appName forKey:@"app"];
    [dic setValue:@"nonprivate" forKey:@"type"];
    [dic setValue:tcUrl forKey:@"tcUrl"];
    [archiver encodeObject:dic];
    return [archiver data];
}
/**
 *  用于拼装RTMP释放命令的AMF0数据结构
 *
 *  @param streamName 流名
 *
 *  @return NSData
 */
+(NSData *)releaseStreamData:(NSString *)streamName{
    AMFArchiver *archiver=[[AMFArchiver alloc] initForWritingWithMutableData:[NSMutableData data]
                                                                    encoding:kAMF0Encoding];
    /**
     * releaseStream命令结构
     | Field Name | Type | Description |
     |命令名称 | String | 命令的名称. 设置成 "releaseStream"
     |事务ID |Number| int |
     |命令对象 | Object | 键值对的命令信息 |
     |流名 | String | streamName |
     */
    [archiver encodeObject:@"releaseStream"];
    [archiver encodeObject:[NSNumber numberWithInt:++sendTransactionID]];
    [archiver encodeUnsignedChar:kAMF0NullType];
    [archiver encodeObject:streamName];
    return [archiver data];
}/**
  *  用于拼装RTMP fcPublish命令的AMF0数据结构
  *
  *  @param streamName 流名
  *
  *  @return NSData
  */
+(NSData *)fcPublishData:(NSString *)streamName{
    AMFArchiver *archiver=[[AMFArchiver alloc] initForWritingWithMutableData:[NSMutableData data]
                                                                    encoding:kAMF0Encoding];
    /**
     * FCPublish命令结构
     | Field Name | Type | Description |
     |命令名称 | String | 命令的名称. 设置成 "FCPublish"
     |事务ID |Number| int |
     |命令对象 | Object | 键值对的命令信息 |
     |流名 | String | streamName |
     */
    [archiver encodeObject:@"FCPublish"];
    [archiver encodeObject:[NSNumber numberWithInt:++sendTransactionID]];
    [archiver encodeUnsignedChar:kAMF0NullType];
    [archiver encodeObject:streamName];
    return [archiver data];
}
/**
 *  用于拼装RTMP createStream命令的AMF0数据结构
 *
 *  @return NSData
 */
+(NSArray *)createStreamData{
    AMFArchiver *archiver=[[AMFArchiver alloc] initForWritingWithMutableData:[NSMutableData data]
                                                                    encoding:kAMF0Encoding];
    /**
     * createStream命令结构
     | Field Name | Type | Description |
     |命令名称 | String | 命令的名称. 设置成 "createStream"
     |事务ID |Number| int |
     |命令对象 | Object | 键值对的命令信息 |
     */
    [archiver encodeObject:@"createStream"];
    [archiver encodeObject:[NSNumber numberWithInt:++sendTransactionID]];
    [archiver encodeUnsignedChar:kAMF0NullType];
    NSMutableArray *array=[NSMutableArray new];
    [array addObject:[archiver data]];
    [array addObject:[NSNumber numberWithInt:sendTransactionID]];
    return array;
}
/**
 *  用于拼装RTMP checkbw命令的AMF0数据结构
 *
 *  @return NSData
 */
+(NSData *)checkbwData{
    AMFArchiver *archiver=[[AMFArchiver alloc] initForWritingWithMutableData:[NSMutableData data]
                                                                    encoding:kAMF0Encoding];
    /**
     * _checkbw命令结构
     | Field Name | Type | Description |
     |命令名称 | String | 命令的名称. 设置成 "_checkbw"
     |事务ID |Number| int |
     |命令对象 | Object | 键值对的命令信息 |
     */
    [archiver encodeObject:@"_checkbw"];
    [archiver encodeObject:[NSNumber numberWithInt:++sendTransactionID]];
    [archiver encodeUnsignedChar:kAMF0NullType];
    return [archiver data];
}
/**
 *  用于拼装RTMP deleteStream命令的AMF0数据结构
 *
 *  @param streamID 流ID
 *
 *  @return NSData
 */
+(NSData *)deleteStreamData:(int)streamID{
    AMFArchiver *archiver=[[AMFArchiver alloc] initForWritingWithMutableData:[NSMutableData data]
                                                                    encoding:kAMF0Encoding];
    /**
     * deleteStream命令结构
     | Field Name | Type | Description |
     |命令名称 | String | 命令的名称. 设置成 "deleteStream"
     |事务ID |Number| int |
     |命令对象 | Object | 键值对的命令信息 |
     */
    [archiver encodeObject:@"deleteStream"];
    [archiver encodeObject:[NSNumber numberWithInt:sendTransactionID++]];
    [archiver encodeUnsignedChar:kAMF0NullType];
    [archiver encodeObject:[NSNumber numberWithInt:streamID]];
    sendTransactionID=1;
    return [archiver data];
}
/**
 *  用于拼装RTMP publis命令的AMF0数据结构
 *
 *  @param streamName 流名
 *
 *  @return NSData
 */
+(NSData *)publishData:(NSString *)streamName{
    AMFArchiver *archiver=[[AMFArchiver alloc] initForWritingWithMutableData:[NSMutableData data]
                                                                    encoding:kAMF0Encoding];
    /**
     * publish命令结构
     | Field Name | Type | Description |
     |命令名称 | String | 命令的名称. 设置成 "publish"
     |事务ID |Number| int |
     |命令对象 | Object | 键值对的命令信息 |
     |流名 | String | streamName |
     |流类型 | String | live |
     */
    [archiver encodeObject:@"publish"];
    [archiver encodeObject:[NSNumber numberWithInt:++sendTransactionID]];
    [archiver encodeUnsignedChar:kAMF0NullType];
    [archiver encodeObject:streamName];
    [archiver encodeObject:@"live"];
    return [archiver data];
}
/**
 *  用于拼装RTMP FCUnPublish命令的AMF0数据结构
 *
 *  @param streamName 流名
 *
 *  @return NSData
 */
+(NSData *)fcunPublishData:(NSString *)streamName{
    AMFArchiver *archiver=[[AMFArchiver alloc] initForWritingWithMutableData:[NSMutableData data]
                                                                    encoding:kAMF0Encoding];
    /**
     * FCUnpublish命令结构
     | Field Name | Type | Description |
     |命令名称 | String | 命令的名称. 设置成 "FCUnpublish"
     |事务ID |Number| int |
     |命令对象 | Object | 键值对的命令信息 |
     |流名 | String | streamName |
     */
    [archiver encodeObject:@"FCUnpublish"];
    [archiver encodeObject:[NSNumber numberWithInt:++sendTransactionID]];
    [archiver encodeUnsignedChar:kAMF0NullType];
    [archiver encodeObject:streamName];
    return [archiver data];
}
/**
 *  用于拼装RTMP setDataFrame命令的AMF0数据结构,用于设置元数据metadata，音视频参数
 *
 *  @param videoConfig 视频信息
 *  @param audioConfig 音频信息
 *  @return NSData
 */
+(NSData *)setDataFrameData:(LFVideoConfig *)videoConfig
                audioConfig:(LFAudioConfig *)audioConfig{
    /**
     * setDataFrame命令结构
     | Field Name | Type | Description |
     |命令名称 | String | 命令的名称. 设置成 "@setDataFrame"
     |设置元数据 | String | 设置成 "onMetaData"
     |数组 |array| 具体音视频参数 |
     */
    AMFArchiver *archiver=[[AMFArchiver alloc] initForWritingWithMutableData:[NSMutableData data]
                                                                    encoding:kAMF0Encoding];
    [archiver encodeObject:@"@setDataFrame"];
    [archiver encodeObject:@"onMetaData"];
    NSMutableArray *array=[NSMutableArray new];
    [array addObject:@{@"width":[NSNumber numberWithInt:videoConfig.videoSize.width]}];
    [array addObject:@{@"height":[NSNumber numberWithInt:videoConfig.videoSize.height]}];
    [array addObject:@{@"videodatarate":[NSNumber numberWithInt:videoConfig.bitRate]}];
    [array addObject:@{@"framerate":[NSNumber numberWithInt:videoConfig.frameRate]}];
    //编码格式7代表h264
    [array addObject:@{@"videocodecid":[NSNumber numberWithInt:7]}];
    [array addObject:@{@"audiodatarate":[NSNumber numberWithInt:audioConfig.bitRate]}];
    [array addObject:@{@"audiosamplerate":[NSNumber numberWithInt:audioConfig.sampleRate]}];
    [array addObject:@{@"audiosamplesize":[NSNumber numberWithInt:audioConfig.bitDepth]}];
    if(audioConfig.channel==LFAudioConfigChannelStereo){
        [array addObject:@{@"stereo":[NSNumber numberWithBool:YES]}];
    }else{
        [array addObject:@{@"stereo":[NSNumber numberWithBool:NO]}];
    }
    //10代表aac
    [array addObject:@{@"audiocodecid":[NSNumber numberWithInt:10]}];
    [archiver encodeObject:array];
    return [archiver data];
}
/**
 *  FLV AAC音频同步包。 不论向 RTMP 服务器推送音频还是视频，都需要按照 FLV 的格式进行封包。因此，在我们向服务器推送第一个 AAC包之前，
 *  需要首先推送一个音频 Tag [AAC Sequence Header].
 *  具体内容见FLV官方文档AAC Sequence Header章节
 *  @return NSData
 */
+(NSData *)flvAACSequenceHeader{
    NSMutableData *data=[NSMutableData data];
    [data setLength:4];
    uint8_t *bytes=[data mutableBytes];
    //首字节高四位为编码类型如AAC则为1010，接下来两位表示采样率如果是44100则为11
    //接下来一位表示采样位元深度如16位用1表示，接下一位是声道数如双声道用1表示
    //那么16位双声道44k采样的AAC编码为0xaf
    bytes[0]=0xaf;
    //第二字节为数据包类型，0为AAC同步包，1为AAC音频数据包
    bytes[1]=0x0;
    //接下来的两字节表示为 AudioSpecificConfig 可以参看ISO AudioSpecificConfig（ISO/IEC 14496-3 中1.6.2.1）
    //5 bit的编码类型AAC-LC对应的值为2二进制表示为00010
    //4 bit的音频采样率441000对应的值为4二进制表示为0100,48000的值为3对应二进制为0011
    //4 bit的声道数 双声道对应的值为2二进制表示为0010
    //1 bit的IMDCT窗口长度固定为0
    //1 bit的表明是否依赖corecoder固定为0
    //1 bit的扩展标示，如果是AAC-LC这里必须是0
    
    if([DevicePlatform isIphone6sHLevel]){
        bytes[2]=0x11;
        bytes[3]=0x90;
    }else{
        bytes[2]=0x12;
        bytes[3]=0x10;
    }
    return data;
}
/**
 *  使用FLV封装AAC格式的音频包
 *
 *  @param encodeData AAC格式的音频数据
 *
 *  @return NSData
 */
+(NSData *)flvAACAudioData:(NSData *)encodeData{
    NSMutableData *packetData=[NSMutableData new];
    //普通音频数据包由两字节的音频头和具体的数据构成
    [packetData setLength:2];
    uint8_t *bytes=[packetData mutableBytes];
    //首字节高四位为编码类型如AAC则为1010，接下来两位表示采样率如果是44100则为11
    //接下来一位表示采样位元深度如16位用1表示，接下一位是声道数如双声道用1表示
    //那么16位双声道44k采样的AAC编码为0xaf
    bytes[0]=0xaf;
    //第二字节为数据包类型，0为AAC同步包，1为AAC音频数据包
    bytes[1]=0x1;
    [packetData appendBytes:encodeData.bytes length:encodeData.length];
    return packetData;
}
/**
 *  FLV 视频频同步包 不论向 RTMP 服务器推送音频还是视频，都需要按照 FLV 的格式进行封包。
 *  具体内容见FLV官方文档Video Tags章节
 */
+(NSData *)flvVideoSequenceHeader:(LFVideoEncodeInfo *)info{
    //视频同步包包含如下内容：
    //4位的FrameType 由于采用可以seekable的avc故为1
    //4位的codescID由于是AVC(h.264)故是7
    //1字节的AVCPacketType 如果是同步包则为0如果是普通数据包则为1
    //3字节的Composition Time 如果同步包则为0
    //1字节的configurationVersion 固定为1
    //1字节的sps[1]
    //1字节的sps[2];
    //1字节的sps[3];
    //6位全是1的标志位
    //2字节的lengthSizeMinusOne 一般为3
    //3字节的全是1的标示位
    //5字节的sps的个数一般为1
    //不固定长的sps_size+sps数据
    //8字节的pps个数一般为1
    //不固定长的pps_size+pps数据
    uint8_t header[1024]={0};
    int i=0;
    header[i++]=0x17;//FrameType和codescID
    header[i++]=0x0;//AVCPacketType 如果是同步包则为0如果是普通数据包则为1
    i+=3;//3字节的Composition Time 全为0
    //后续为AVCDecoderConfigurationRecord的内容，参见ISO 14496-15, 5.2.4.1
    header[i++]=0x01;//configurationVersion 固定为1
    const uint8_t *sps=[info.sps bytes];
    header[i++]=sps[1];
    header[i++]=sps[2];
    header[i++]=sps[3];
    header[i++]=0xff;
    header[i++]=0xe1;
    //两字节的sps长度
    short int spsLength=(short int)info.sps.length;
    header[i++]=spsLength>>8;
    header[i++]=spsLength&0xff;
    memcpy(&header[i], sps, info.sps.length);
    i+=info.sps.length;
    header[i++]=0x01;
    //两字节的pps长度
    short int ppsLength=(short int)info.pps.length;
    header[i++]=ppsLength>>8;
    header[i++]=ppsLength&0xff;
    memcpy(&header[i], [info.pps bytes], info.pps.length);
    i+=info.pps.length;
    return [NSData dataWithBytes:&header length:i];
}
/**
 *  使用FLV封装h264格式的视频包
 *
 *  @param encodeData h264格式的视频数据
 *
 *  @return NSData
 */
+(NSData *)flvVideoData:(LFVideoEncodeInfo *)info{
    NSMutableData *data=[NSMutableData new];
    [data setLength:9];
    uint8_t *body=data.mutableBytes;
    if (info.isKeyFrame) {
        body[0] = 0x17;//四位的fram type为1（关键帧key frame），四位的codescID为7，则组合为0x17
    } else {
        body[0] = 0x27;//四位的fram type为2（I帧 inter frame），四位的codescID为7，则组合为0x27
    }
    body[1] = 0x01;//AVCPacketType 普通数据包则为1(AVC NALU)
    body[2] = 0x00;//3字节的Composition Time 全为0
    body[3] = 0x00;
    body[4] = 0x00;
    //四字节的NALU长度
    body[5] = (info.data.length >> 24) & 0xff;
    body[6] = (info.data.length >> 16) & 0xff;
    body[7] = (info.data.length >>  8) & 0xff;
    body[8] = (info.data.length) & 0xff;
    [data appendData:info.data];
    return data;
}
/**
 *  用于拼装RTMP getStreamLength命令的AMF0数据结构
 *
 *  @param streamName 流名
 *
 *  @return NSData
 */
+(NSData *)getStreamLengthData:(NSString *)streamName{
    AMFArchiver *archiver=[[AMFArchiver alloc] initForWritingWithMutableData:[NSMutableData data]
                                                                    encoding:kAMF0Encoding];
    /**
     * FCUnpublish命令结构
     | Field Name | Type | Description |
     |命令名称 | String | 命令的名称. 设置成 "getStreamLength"
     |事务ID |Number| int |
     |命令对象 | Object | 键值对的命令信息 |
     |流名 | String | streamName |
     */
    [archiver encodeObject:@"getStreamLength"];
    [archiver encodeObject:[NSNumber numberWithInt:++sendTransactionID]];
    [archiver encodeUnsignedChar:kAMF0NullType];
    [archiver encodeObject:streamName];
    return [archiver data];
}
/**
 *  用于拼装RTMP play命令的AMF0数据结构
 *
 *  @param streamName 流名
 *
 *  @return NSData
 */
+(NSData *)playData:(NSString *)streamName{
    AMFArchiver *archiver=[[AMFArchiver alloc] initForWritingWithMutableData:[NSMutableData data]
                                                                    encoding:kAMF0Encoding];
    /**
     * FCUnpublish命令结构
     | Field Name | Type | Description |
     |命令名称 | String | 命令的名称. 设置成 "play"
     |事务ID |Number| int |
     |命令对象 | Object | 键值对的命令信息 |
     |流名 | String | streamName |
     */
    [archiver encodeObject:@"play"];
    [archiver encodeObject:[NSNumber numberWithInt:++sendTransactionID]];
    [archiver encodeUnsignedChar:kAMF0NullType];
    [archiver encodeObject:streamName];
    return [archiver data];
}
/**
 *  用于拼装RTMP 用户控制事件的setBufferLength，这个事件在服务器开始处理流数据前发送。类型为3占两字节，事件数据的前 4 字节表示流 ID,接下来的4 字节表示缓冲区的大小(单位是毫秒)。
 *
 *  @param streamid 流ID
 *  @param  buffersize 缓冲区大小
 *  @return NSData
 */
+(NSData *)setBufferLengthData:(uint32_t)streamId bufferSize:(uint32_t)bufferSize{
    NSMutableData *data=[NSMutableData data];
    [data setLength:10];
    uint8_t *bytes=[data mutableBytes];
    //setBufferLength在User Control Message Events对应的类型为3
    bytes[0]=0x0;
    bytes[1]=0x3;
    bytes[2]=0x0|(streamId>>24);
    bytes[3]=0x0|(streamId>>16);
    bytes[4]=0x0|(streamId>>8);
    bytes[5]=0x0|streamId;
    bytes[6]=0x0|(bufferSize>>24);
    bytes[7]=0x0|(bufferSize>>16);
    bytes[8]=0x0|(bufferSize>>8);
    bytes[9]=0x0|bufferSize;
    return data;

}
/**
 *  用于拼装RTMP pause命令的AMF0数据结构
 *
 *  @param isFlag 暂停流还是继续
 *  @param milliSeconds 流暂停或者继续播放的毫秒数
 
 *  @return NSData
 */
+(NSData *)pauseData:(BOOL)isFlag milliSeconds:(int)milliSeconds{
    AMFArchiver *archiver=[[AMFArchiver alloc] initForWritingWithMutableData:[NSMutableData data]
                                                                    encoding:kAMF0Encoding];
    /**
     * pause命令结构
     | Field Name | Type | Description |
     |命令名称 | String | 命令的名称. 设置成 "pause"
     |事务ID |Number| int |
     |命令对象 | Object | 键值对的命令信息 |
     |Pause/Unpause | Boolean | 暂停流还是继续 |
     |milliSeconds | Number | 流暂停或者继续播放的毫秒数|
     */
    [archiver encodeObject:@"pause"];
    [archiver encodeObject:[NSNumber numberWithInt:++sendTransactionID]];
    [archiver encodeUnsignedChar:kAMF0NullType];
    [archiver encodeBool:isFlag];
    [archiver encodeObject:[NSNumber numberWithInt:milliSeconds]];
    return [archiver data];
}
@end
