//
//  RtmpChunFormat.h
//  myrtmp
//
//  Created by liuf on 16/7/22.
//
//
/**
 *  块格式，包含了Basic Header，Message Header,ExtendedTimestamp,Chunk Data 四部分组成
 *  提供了最后合并为一个完整块的方法
 */

#import <Foundation/Foundation.h>
#import "LFRtmpChunkData.h"
#import "LFRtmpBasicHeader.h"
@interface LFRtmpChunkFormat : NSObject

@property (assign,nonatomic) uint32_t inChunkSize;//接收到的包大小
@property (assign,nonatomic) uint32_t outChunkSize;//发送的包大小
@property (assign,nonatomic) uint32_t abortChunkStreamID;
@property (assign,nonatomic) uint32_t acknowledgementSeq;
@property (assign,nonatomic) uint32_t windowAckSize;
@property (assign,nonatomic) uint32_t bandWidth;
@property (assign,nonatomic) LFRtmpBandWidthLimitType bandWidthLimiType;
@property (assign,nonatomic) BOOL isStreamBegin;
/**
 *  用于RTMP连接的命令数据块
 *
 *  @param appName 例如有推流路径为rtmp://xx.com/userlive/liuf，appName则为userlive
 *  @param tcUrl 例如有推流路径为rtmp://xx.com/userlive/liuf，tcUrl则为rtmp://xx.com/userlive
 *  @return NSData。
 */
-(NSData *)connectChunkFormat:(NSString *)appName tcUrl:(NSString *)tcUrl;
/**
 *  用于RTMP释放流的命令数据块
 *
 *  @param streamName 流名
 *
 *  @return NSData
 */
-(NSData *)releaseStreamChunkFormat:(NSString *)streamName;
/**
 *  用于RTMP fcPublish的命令数据块
 *
 *  @param streamName 流名
 *
 *  @return NSData
 */
-(NSData *)fcPublishStreamChunkFormat:(NSString *)streamName;
/**
 *  用于RTMP createStream的命令数据块
 *
 *  @return NSData
 */
-(NSArray *)createStreamChunkForamt;
/**
 *  用于RTMP checkbw的命令数据块
 *
 *  @return NSData
 */
-(NSData *)checkbwChunkForamt;
/**
 *  用于RTMP deleteStream的命令数据块
 *
 *  @return NSData
 */
-(NSData *)deleteStreamForamt:(int)streamID;
/**
 *  用于RTMP publish的命令数据块
 *
 *  @param streamName 流名
 *
 *  @return NSData
 */
-(NSData *)publishStreamChunkFormat:(NSString *)streamName;
/**
 *  用于RTMP fcunpublish的命令数据块
 *
 *  @param streamName 流名
 *
 *  @return NSData
 */
-(NSData *)fcUnPublishStreamChunkFormat:(NSString *)streamName;
/**
 *  FLV AAC音频同步包。 不论向 RTMP 服务器推送音频还是视频，都需要按照 FLV 的格式进行封包。因此，在我们向服务器推送第一个 AAC包之前，
 *  需要首先推送一个音频 Tag [AAC Sequence Header].
 *  具体内容见FLV官方文档AAC Sequence Header章节
 *  @return NSData
 */
/**
 *  用于拼装RTMP setDataFrame命令的AMF0数据结构,用于设置元数据metadata，音视频参数
 *
 *  @param videoConfig 视频信息
 *  @param audioConfig 音频信息
 *  @return NSData
 */
-(NSData *)setDataFrameChunkFormat:(LFVideoConfig *)videoConfig
                       audioConfig:(LFAudioConfig *)audioConfig;
-(NSMutableData *)flvAACSequenceHeader;
/**
 *  使用FLV封装AAC格式的音频包
 *
 *  @param encodeData AAC格式的音频数据
 *
 *  @return NSData
 */
-(NSMutableData *)flvAACAudioData:(NSData *)encodeData;
/**
 *  FLV 视频频同步包
 */
-(NSData *)flvVideoSequenceHeader:(LFVideoEncodeInfo *)info;
/**
 *  使用FLV封装h264格式的视频包
 *
 *  @param encodeData h264格式的视频数据
 *
 *  @return NSData
 */
-(NSData *)flvVideoData:(LFVideoEncodeInfo *)info;
/**
 *  用于拼装RTMP getStreamLength命令的AMF0数据结构
 *
 *  @param streamName 流名
 *  @return NSData
 */
-(NSData *)getStreamLengthChunkFormat:(NSString *)streamName;
/**
 *  用于拼装RTMP play命令的AMF0数据结构
 *
 *  @param streamName 流名
 *  @return NSData
 */
-(NSData *)playChunkFormat:(NSString *)streamName;
/**
 *  用于拼装RTMP 用户控制事件的setBufferLength，这个事件在服务器开始处理流数据前发送。类型为3，事件数据的前 4 字节表示流 ID,接下来的4 字节表示缓冲区的大小(单位是毫秒)。
 *
 *  @param streamid 流ID
 *  @param  buffersize 缓冲区大小
 *  @return NSData
 */
-(NSData *)setBufferLengthChunkFormat:(uint32_t)streamId bufferSize:(uint32_t)bufferSize;
/**
 *  用于拼装RTMP pause命令的AMF0数据结构
 *
 *  @param isFlag 暂停流还是继续
 *  @param milliSeconds 流暂停或者继续播放的毫秒数
 
 *  @return NSData
 */
-(NSData *)pauseChunkFormat:(BOOL)isFlag milliSeconds:(int)milliSeconds;
/**
 *  当前时间戳
 *
 *  @return uint32_t
 */
-(uint32_t)currentTimestamp;
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
+(uint8_t)chunkPacketSplitChar:(LFRtmpBasicHeaderChunkStreamID)chunkStreamID;
@end
