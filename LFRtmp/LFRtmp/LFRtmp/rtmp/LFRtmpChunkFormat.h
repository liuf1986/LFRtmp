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
typedef enum : char {
    LFRtmpSendCommandConnect=0x1,//connect命令
    LFRtmpSendCommandReleaseStream=0x1,//releaseStream命令
    LFRtmpSendCommandFCPublish=0x2,//FCPublish命令
    LFRtmpSendCommandCreateStream=0x3,//createStream命令
    LFRtmpSendCommand_Checkbw=0x4,//_checkbw命令
    LFRtmpSendCommandDeleteStream=0x5,//deleteStream命令
    LFRtmpSendCommandPublishStream=0x6,//publish命令
    LFRtmpSendCommandFCUnPublishStream=0x7,//FCUnpublish命令
    
} LFRtmpSendCommandType;

@protocol LFRtmpChunkFormatDelegate <NSObject>
/**
 *  处理命令消息
 */
-(void)onHandleCommand:(LFRtmpResponseCommand *)command sendCmdType:(LFRtmpSendCommandType)sendCmdType;

@end
@interface LFRtmpChunkFormat : NSObject

@property (assign,nonatomic) uint32_t chunkSize;
@property (assign,nonatomic) uint32_t abortChunkStreamID;
@property (assign,nonatomic) uint32_t acknowledgementSeq;
@property (assign,nonatomic) uint32_t windowAckSize;
@property (assign,nonatomic) uint32_t bandWidth;
@property (assign,nonatomic) LFRtmpBandWidthLimitType bandWidthLimiType;
@property (assign,nonatomic) BOOL isStreamBegin;
@property (weak,nonatomic) id<LFRtmpChunkFormatDelegate>delegate;
/**
 *  用于RTMP连接的命令数据块
 *
 *  @param appName 例如有推流路径为rtmp://userpush.livecdn.cditv.cn/userlive/liuf，appName则为userlive
 *  @param tcUrl 例如有推流路径为rtmp://userpush.livecdn.cditv.cn/userlive/liuf，tcUrl则为rtmp://userpush.livecdn.cditv.cn/userlive
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
-(NSData *)createStreamChunkForamt;
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
 *  处理发出连接请求后服务器的响应
 *
 *  @param packet 数据包
 *  @param size   包的有效位数
 *  @param sendCmdType 发送的命令类型
 *  @return 是否处理成功
 */
-(void)parseResponsePacket:(char *)packet size:(int)size sendCmdType:(LFRtmpSendCommandType)sendCmdType;
/**
 *  FLV AAC音频同步包。 不论向 RTMP 服务器推送音频还是视频，都需要按照 FLV 的格式进行封包。因此，在我们向服务器推送第一个 AAC包之前，
 *  需要首先推送一个音频 Tag [AAC Sequence Header].
 *  具体内容见FLV官方文档AAC Sequence Header章节
 *  @return NSData
 */
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
 *  当前时间戳
 *
 *  @return uint32_t
 */
-(uint32_t)currentTimestamp;
/**
 如果一个包的大小超过chunk size的大小（如果没有设置默认为128b）则128整倍数位上的数据不计入有效数据
 这种数据称为包分隔符，包分隔符的规则为0xc0|chunk stream ID
 例如如果是音视频块流则chunk stream ID为0x4，包分隔符=0xc0|0x2=0xc4
 *
 *  @param chunkStreamID 块流ID
 *
 *  @return 包分隔符
 */
+(uint8_t)chunkPacketSplitChar:(LFRtmpBasicHeaderChunkStreamID)chunkStreamID;
@end
