//
//  LFRtmpChunkData.h
//  myrtmp
//
//  Created by liuf on 16/7/22.
//
//
#define kBandWidthSize @"bandWidthSize"
#define kBandWidthLimitType @"bandWidthLimitType"
#import <Foundation/Foundation.h>
#import "LFRtmpMessageHeader.h"
#import "LFRtmpResponseCommand.h"
#import "LFVideoEncodeInfo.h"
#import "LFVideoConfig.h"
#import "LFAudioConfig.h"
typedef enum : char {
    LFRtmpBandWidthLimitHard=0x0,//0-Hard(硬):对端应该(SHOULD)用指定的窗口大小限制自己的输出带宽。
    LFRtmpBandWidthLimitSoft=0x1,//1-Soft(软):对端应该(SHOULD)使用指定的窗口大小限制自己的输出带宽,如果已经 限制了的则取二者中小值。
    LFRtmpBandWidthLimitDynamic=0x2//2-Dynamic(动态):如果先前的限制类型是是硬,那么把这个消息看成硬类型,否则忽略这 个消息。
} LFRtmpBandWidthLimitType;

/**
 *  用户层面上真正想要发送的与协议无关的数据，长度在(0,chunkSize]之间。
 */
@interface LFRtmpChunkData : NSObject
/**
 *  原始二进制数据
 */
@property (strong,readonly,nonatomic) NSData *data;
/**
 *  初始化
 *
 *  @param data        用于初始化的二进制数据
 *  @param messageType 数据的种类
 *
 *  @return self
 */
-(instancetype)init:(NSData *)data;
/**
 *  处理协议控制消息 Set Chunk Size
 *
 *  @return chunk size大小
 */
-(uint32_t)parseSetChunkSize;
/**
 *  处理协议控制消息 Abort Message
 *
 *  @return 块流 ID，用来通知对端如果正在等待接收消息的块那么就丢弃已通过块流接收到的消息
 */
-(uint32_t)parseAbortMessage;
/**
 *  处理协议控制消息 Acknowledgement
 *
 *  @return 序列号(sequence number,32 位):这个字段包含了目前为止接收到的字节数
 */
-(uint32_t)parseAcknowledgement;
/**
 *  处理协议控制消息 Windows Acknowledgement Size
 *
 *  @return 窗口确认大小
 */
-(uint32_t)parseWindowAckSize;
/**
 *  处理协议控制消息 Set Peer Bandwidth
 *
 *  @return 设置对端带宽大小
 */
-(NSDictionary *)parseBandWidth;
/**
 *  处理用户控制消息，对应推流端不需要处理其他的用户控制消息
 *  @return 服务器告诉客户端流是否已就绪用于通讯
 */
-(BOOL)parseUserCtrlStreamBegin;
/**
 *  处理命令消息body
 *
 *  @return LFRtmpCommand
 */
-(LFRtmpResponseCommand *)parseCommand;
/**
 *  用于拼装RTMP连接命令的AMF0数据结构
 *
 *  @param appName 例如有推流路径为rtmp://xx.com/userlive/liuf，appName则为userlive
 *  @param tcUrl 例如有推流路径为rtmp://xx.com/userlive/liuf，tcUrl则为rtmp://xx.com/userlive
 *  @return NSData。
 */
+(NSData *)connectData:(NSString *)appName tcUrl:(NSString *)tcUrl;
/**
 *  用于拼装RTMP释放命令的AMF0数据结构
 *
 *  @param streamName 流名
 *
 *  @return NSData
 */
+(NSData *)releaseStreamData:(NSString *)streamName;
/**
 *  用于拼装RTMP fcPublish命令的AMF0数据结构
 *
 *  @param streamName 流名
 *
 *  @return NSData
 */
+(NSData *)fcPublishData:(NSString *)streamName;
/**
 *  用于拼装RTMP createStream命令的AMF0数据结构
 *
 *  @return NSData
 */
+(NSArray *)createStreamData;
/**
 *  用于拼装RTMP checkbw命令的AMF0数据结构
 *
 *  @return NSData
 */
+(NSData *)checkbwData;
/**
 *  用于拼装RTMP deleteStream命令的AMF0数据结构
 *
 *  @param streamID 流ID
 *
 *  @return NSData
 */
+(NSData *)deleteStreamData:(int)streamID;
/**
 *  用于拼装RTMP publis命令的AMF0数据结构
 *
 *  @param streamName 流名
 *
 *  @return NSData
 */
+(NSData *)publishData:(NSString *)streamName;
/**
 *  用于拼装RTMP FCUnPublish命令的AMF0数据结构
 *
 *  @param streamName 流名
 *
 *  @return NSData
 */
+(NSData *)fcunPublishData:(NSString *)streamName;

/**
 *  用于拼装RTMP setDataFrame命令的AMF0数据结构,用于设置元数据metadata，音视频参数
 *
 *  @param videoConfig 视频信息
 *  @param audioConfig 音频信息
 *  @return NSData
 */
+(NSData *)setDataFrameData:(LFVideoConfig *)videoConfig
                audioConfig:(LFAudioConfig *)audioConfig;
/**
 *  FLV AAC音频同步包。 不论向 RTMP 服务器推送音频还是视频，都需要按照 FLV 的格式进行封包。因此，在我们向服务器推送第一个 AAC包之前，
 *  需要首先推送一个音频 Tag [AAC Sequence Header].
 *  具体内容见FLV官方文档AAC Sequence Header章节
 *  @return NSData
 */
+(NSData *)flvAACSequenceHeader;
/**
 *  使用FLV封装AAC格式的音频包
 *
 *  @param encodeData AAC格式的音频数据
 *
 *  @return NSData
 */
+(NSData *)flvAACAudioData:(NSData *)encodeData;

/**
 *  FLV 视频频同步包
 */
+(NSData *)flvVideoSequenceHeader:(LFVideoEncodeInfo *)info;
/**
 *  使用FLV封装h264格式的视频包
 *
 *  @param encodeData h264格式的视频数据
 *
 *  @return NSData
 */
+(NSData *)flvVideoData:(LFVideoEncodeInfo *)info;
/**
 *  用于拼装RTMP getStreamLength命令的AMF0数据结构
 *
 *  @param streamName 流名
 *
 *  @return NSData
 */
+(NSData *)getStreamLengthData:(NSString *)streamName;
/**
 *  用于拼装RTMP play命令的AMF0数据结构
 *
 *  @param streamName 流名
 *
 *  @return NSData
 */
+(NSData *)playData:(NSString *)streamName;
/**
 *  用于拼装RTMP 用户控制事件的setBufferLength，这个事件在服务器开始处理流数据前发送。类型为3，事件数据的前 4 字节表示流 ID,接下来的4 字节表示缓冲区的大小(单位是毫秒)。
 *
 *  @param streamid 流ID
 *  @param  buffersize 缓冲区大小
 *  @return NSData
 */
+(NSData *)setBufferLengthData:(uint32_t)streamId bufferSize:(uint32_t)bufferSize;
/**
 *  用于拼装RTMP pause命令的AMF0数据结构
 *
 *  @param isFlag 暂停流还是继续
 *  @param milliSeconds 流暂停或者继续播放的毫秒数
 
 *  @return NSData
 */
+(NSData *)pauseData:(BOOL)isFlag milliSeconds:(int)milliSeconds;
@end
