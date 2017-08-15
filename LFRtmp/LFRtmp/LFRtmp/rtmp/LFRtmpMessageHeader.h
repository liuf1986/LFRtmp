//
//  LFRtmpMessageHeader.h
//  myrtmp
//
//  Created by liuf on 16/7/22.
// 
//
/**
 *   Message Header（消息的头信息）：
 包含了要发送的实际信息（可能是完整的，也可能是一部分）的描述信息。Message Header的格式和长度取决于Basic Header的chunk type，共有4种不同的格式，由上面所提到的Basic Header中的fmt字段控制。其中第一种格式可以表示其他三种表示的所有数据，但由于其他三种格式是基于对之前chunk的差量化的表示，因此可以更简洁地表示相同的数据，实际使用的时候还是应该采用尽量少的字节表示相同意义的数据。以下按照字节数从多到少的顺序分别介绍这4种格式的Message Header。
 Type＝0:
 type=0时Message Header占用11个字节，其他三种能表示的数据它都能表示，但在chunk stream的开始的第一个chunk和头信息中的时间戳后退（即值与上一个chunk相比减小，通常在回退播放的时候会出现这种情况）的时候必须采用这种格式。
 timestamp（时间戳）：占用3个字节，因此它最多能表示到16777215=0xFFFFFF=2
 24-1, 当它的值超过这个最大值时，这三个字节都置为1，这样实际的timestamp会转存到Extended Timestamp字段中，接受端在判断timestamp字段24个位都为1时就会去Extended timestamp中解析实际的时间戳。
 message length（消息数据的长度）：占用3个字节，表示实际发送的消息的数据如音频帧、视频帧等数据的长度，单位是字节。注意这里是Message的长度，也就是chunk属于的Message的总数据长度，而不是chunk本身Data的数据的长度。
 message type id(消息的类型id)：占用1个字节，表示实际发送的数据的类型，如8代表音频数据、9代表视频数据。
 msg stream id（消息的流id）：占用4个字节，表示该chunk所在的流的ID，和Basic Header的CSID一样，它采用小端存储的方式，
 Type = 1:
 type=1时Message Header占用7个字节，省去了表示msg stream id的4个字节，表示此chunk和上一次发的chunk所在的流相同，如果在发送端只和对端有一个流链接的时候可以尽量去采取这种格式。
 timestamp delta：占用3个字节，注意这里和type＝0时不同，存储的是和上一个chunk的时间差。类似上面提到的timestamp，当它的值超过3个字节所能表示的最大值时，三个字节都置为1，实际的时间戳差值就会转存到Extended Timestamp字段中，接受端在判断timestamp delta字段24个位都为1时就会去Extended timestamp中解析时机的与上次时间戳的差值。
 Type = 2:
 type=2时Message Header占用3个字节，相对于type＝1格式又省去了表示消息长度的3个字节和表示消息类型的1个字节，表示此chunk和上一次发送的chunk所在的流、消息的长度和消息的类型都相同。余下的这三个字节表示timestamp delta，使用同type＝1
 Type = 3
 0字节,它表示这个chunk的Message Header和上一个是完全相同的，自然就不用再传输一遍了。当它跟在Type＝0的chunk后面时，表示和前一个chunk的时间戳都是相同的。什么时候连时间戳都相同呢？就是一个Message拆分成了多个chunk，这个chunk和上一个chunk同属于一个Message。而当它跟在Type＝1或者Type＝2的chunk后面时，表示和前一个chunk的时间戳的差是相同的。比如第一个chunk的Type＝0，timestamp＝100，第二个chunk的Type＝2，timestamp delta＝20，表示时间戳为100+20=120，第三个chunk的Type＝3，表示timestamp delta＝20，时间戳为120+20=140
 */
#import <Foundation/Foundation.h>
#import "LFRtmpExtendedTimestamp.h"
//三字节能表示的最大值
#define kMessageThreeByteMax 16777215
typedef enum : char {
    
    //协议控制消息1,设置chunk中Data字段所能承载的最大字节数，默认为128B，通信过程中可以通过发送该消息来设置chunk Size的大小（不得小于128B），而且通信双方会各自维护一个chunkSize，两端的chunkSize是独立的。比如当A想向B发送一个200B的Message，但默认的chunkSize是128B，因此就要将该消息拆分为Data分别为128B和72B的两个chunk发送，如果此时先发送一个设置chunkSize为256B的消息，再发送Data为200B的chunk，本地不再划分Message，B接受到Set Chunk Size的协议控制消息时会调整的接受的chunk的Data的大小，也不用再将两个chunk组成为一个Message。
    LFRtmpProControlSetChunkSizeMessage=0x1,
    //协议控制消息2,Abort Message，当一个Message被切分为多个chunk，接受端只接收到了部分chunk时，发送该控制消息表示发送端不再传输同Message的chunk，接受端接收到这个消息后要丢弃这些不完整的chunk。Data数据中只需要一个CSID，表示丢弃该CSID的所有已接收到的chunk
    LFRtmpProControlAbortMessage=0x2,
    //协议控制消息3，Acknowledgement message，当收到对端的消息大小等于窗口大小（Window Size）时接受端要回馈一个ACK给发送端告知对方可以继续发送数据。窗口大小就是指收到接受端返回的ACK前最多可以发送的字节数量，返回的ACK中会带有从发送上一个ACK后接收到的字节数。
    LFRtmpProControlAckMessage=0x3,
    //协议控制消息5，Window Acknowledgement Size发送端在接收到接受端返回的两个ACK间最多可以发送的字节数
    LFRtmpProControlWindowAckSizeMessage=0x5,
    //协议控制消息6，Set Peer Bandwidth(Message Type ID=6):限制对端的输出带宽。接受端接收到该消息后会通过设置消息中的Window ACK Size来限制已发送但未接受到反馈的消息的大小来限制发送端的发送带宽。如果消息中的Window ACK Size与上一次发送给发送端的size不同的话要回馈一个Window Acknowledgement Size的控制消息。
    LFRtmpProControlSetPeerBandWidthMessage=0x6,
    //用户控制消息，告知对方执行该信息中包含的用户控制事件，比如Stream Begin事件告知对方流信息开始传输。和前面提到的协议控制信息（Protocol Control Message）不同，这是在RTMP协议层的，而不是在RTMP chunk流协议层的，这个很容易弄混。该信息在chunk流中发送时，Message Stream ID=0,Chunk Stream Id=2,Message Type Id=4
    LFRtmpUserControlMessage=0x4,
    //音频信息
    LFRtmpAudioMessage=0x8,
    //视频信息
    LFRtmpVideoMessage=0x9,
    //数据消息,传递一些元数据（MetaData，比如视频名，分辨率等等）或者用户自定义的一些消息
    LFRtmpDataMessage=0x12,
    //命令消息,表示在客户端盒服务器间传递的在对端执行某些操作的命令消息，如connect表示连接对端，对端如果同意连接的话会记录发送端信息并返回连接成功消息，publish表示开始向对方推流，接受端接到命令后准备好接受对端发送的流信息，后面会对比较常见的Command Message具体介绍。当信息使用AMF0编码时，Message Type ID＝20，AMF3编码时Message Type ID＝17.
    LFRtmpCommandMessage=0x14,
    //未知类型
    LFRtmpMessageHeaderTypeUnkonwn=0x7f
} LFRtmpMessageType;

typedef enum : char {
    LFRtmpMessageHeaderSizeLarge=11,
    LFRtmpMessageHeaderSizeMedium=7,
    LFRtmpMessageHeaderSizeSmall=3,
} LFRtmpMessageHeaderDataSize;

typedef enum : char {
    LFRtmpBasicHeaderFmtLarge=0x0,
    LFRtmpBasicHeaderFmtMedium=0x1,
    LFRtmpBasicHeaderFmtSmall=0x2,
    LFRtmpBasicHeaderFmtMin=0x3,
    LFRtmpBasicHeaderFmtUnkonwn=0x7f //未知类型
} LFRtmpBasicHeaderFmtType;

@interface LFRtmpMessageHeader : NSObject
@property (assign,nonatomic,readonly) uint32_t timestamp;
//是实际发送数据的大小,如果一个包的大小超过chunk size的大小 则需要添加包分隔符，包分隔符的规则为0xc0|chunk stream ID
//例如如果是协议控制块流则chunk stream ID为0x2，包分隔符=0xc0|0x2=0xc2
//每两个分隔符之前的数据量是chunk size 的大小，而在整个数据包中分隔符的下标位置的规律
//为chunk size，(chunk size)*2+1，(chunk size)*3+2 。。。这个规律
@property (assign,nonatomic) uint32_t length;
@property (assign,nonatomic) LFRtmpMessageType typeID;
@property (assign,nonatomic) uint32_t streamID;//它采用小端存储的方式
@property (assign,nonatomic,readonly) LFRtmpBasicHeaderFmtType fmtType;
@property (strong,nonatomic) LFRtmpExtendedTimestamp *extendTimestamp;//扩展时间
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
          timestamp:(uint32_t)timestamp;
/**
 *  创建messageHeader的快捷方式
 *
 *  @param fmtType fmt类型
 *  @param data    数据
 *
 *  @return self
 */
+(instancetype)messageHeader:(LFRtmpBasicHeaderFmtType)fmtType data:(NSData *)data;
/**
 *  返回message header数据
 *
 *  @return 返回message header数据
 */
-(NSData *)data;
@end
