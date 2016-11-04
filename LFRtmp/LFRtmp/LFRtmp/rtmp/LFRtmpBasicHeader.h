//
//  LFRtmpBasicHeader.h
//  myrtmp
//
//  Created by liuf on 16/7/22.
// 
//
/**
 * Basic Header(基本的头信息):
 包含了chunk stream ID（流通道Id）和chunk type（chunk的类型），chunk stream id一般被简写为CSID，用来唯一标识一个特定的流通道，
 chunk type决定了后面Message Header的格式。Basic Header的长度可能是1，2，或3个字节，其中chunk type的长度是固定的
 （占2位，注意单位是位，bit），Basic Header的长度取决于CSID的大小,在足够存储这两个字段的前提下最好用尽量少的字节从而减少由于引入
 Header增加的数据量。
 RTMP协议支持用户自定义［3，65599］之间的CSID，0，1，2由协议保留表示特殊信息。0代表Basic Header总共要占用2个字节，CSID在［64，319］之间，1代表占用3个字节，CSID在［64，65599］之间，2代表该chunk是控制信息和一些命令信息，后面会有详细的介绍。
 chunk type的长度固定为2位，因此CSID的长度是（6=8-2）、（14=16-2）、（22=24-2）中的一个。
 当Basic Header为1个字节时，CSID占6位，6位最多可以表示64个数，因此这种情况下CSID在［0，63］之间，其中用户可自定义的范围为［3，63］。
 当Basic Header为2个字节时，CSID占14位，此时协议将与chunk type所在字节的其他位都置为0，剩下的一个字节来表示CSID－64，这样共有8个字
 节来存储CSID，8位可以表示［0，255］共256个数，因此这种情况下CSID在［64，319］，其中319=255+64。当Basic Header为3个字节时，
 CSID占22位，此时协议将［2，8］字节置为1，余下的16个字节表示CSID－64，这样共有16个位来存储CSID，16位可以表示［0，65535］共65536个
 数，因此这种情况下CSID在［64，65599］，其中65599=65535+64，需要注意的是，Basic Header是采用小端存储的方式，越往后的字节数量级越
 高，因此通过这3个字节每一位的值来计算CSID时，应该是:<第三个字节的值>x256+<第二个字节的值>+64.可以看到2个字节和3个字节的
 Basic Header所能表示的CSID是有交集的［64，319］，但实际实现时还是应该秉着最少字节的原则使用2个字节的表示方式来表示［64，319］的
 CSID。
 */
#import <Foundation/Foundation.h>
#import "LFRtmpChunkData.h"
#import "LFRtmpMessageHeader.h"

typedef enum : char {
    LFRtmpBasicHeaderByteCount1=0x1,//basic header占1字节
    LFRtmpBasicHeaderByteCount2=0x2,//basic header占2字节
    LFRtmpBasicHeaderByteCount3=0x3//basic header占3字节
} LFRtmpBasicHeaderByteCount;

typedef enum : int {
    LFRtmpBasicHeaderProControlStreamID=0x2,//协议控制块流ID
    LFRtmpBasicHeaderCommandStreamID=0x3, //控制块流的ID
    LFRtmpBasicHeaderMediaStreamID=0x4 //音视频块流的ID
} LFRtmpBasicHeaderChunkStreamID;
@interface LFRtmpBasicHeader : NSObject

@property (assign,nonatomic,readonly) LFRtmpBasicHeaderFmtType fmtType;
@property (assign,nonatomic,readonly) LFRtmpBasicHeaderByteCount byteCount;
@property (assign,nonatomic,readonly) LFRtmpBasicHeaderChunkStreamID chunkStreamID;//采用小端存储的方式
//其他挂载属性 和类定向本身无关
@property (strong,nonatomic) LFRtmpMessageHeader *messageHeader;
@property (strong,nonatomic) LFRtmpChunkData *chunkData;
/**
 *  初始化
 *
 *  @param fmtType          fmt类型
 *  @param chunkStreamID id值
 *  @param byteCount     basic header所占的字节数
 *
 *  @return self
 */
-(instancetype)init:(LFRtmpBasicHeaderFmtType)fmtType
      chunkStreamID:(LFRtmpBasicHeaderChunkStreamID)chunkStreamID
          byteCount:(LFRtmpBasicHeaderByteCount)byteCount;
/**
 *  通过一字节的数据解析出实例对象
 *
 *  @param headerData 一字节数据
 *
 *  @return self
 */
+(instancetype)basicHeader:(uint8_t)headerData;
/**
 *  返回basic header数据
 *
 *  @return 返回basic header数据
 */
-(NSData *)data;
@end
