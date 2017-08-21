//
//  RtmpService.m
//  myrtmp
//
//  Created by liuf on 16/7/15.
//
//
#define RTMP_RCVTIMEO 10
#define RTMP_SENDTIMEO 10
#define RTMP_HANDSHAKE_BITSIZE 1536
#define LFRTMPSERVICE_LOCK dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
#define LFRTMPSERVICE_UNLOCK dispatch_semaphore_signal(_semaphore);
#import "LFRtmpPlayer.h"
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <netinet/tcp.h>
#import "LFRtmpChunkFormat.h"
#import "LFRtmpUrlParser.h"
#import "LFRTMPReadBuffer.h"
#import "LFPlayConfig.h"
#import "LFAudioDataParser.h"
#import "LFVideoDataParser.h"
#import "MCAudioOutputQueue.h"
#import "LFVideoPacketData.h"
#import "LFVideoDecode.h"
#import "AAPLEAGLLayer.h"
@interface LFRtmpPlayer()<LFVideoDecodeDelegate>
@end
@implementation LFRtmpPlayer
{
    int _socket;//socket通道描述符
    dispatch_queue_t _qunue;
    dispatch_semaphore_t _semaphore;
    LFRtmpChunkFormat *_rtmpChunkFormat;
    BOOL _isPlayReady;
    BOOL _isSocketConnect;
    BOOL _isListenSocket;
    int _streamID;
    int _createStreamTransactionId;//createStream对应的事务id
    LFPlayConfig *_playConfig;
    MCAudioOutputQueue *_audioOutputQueue;
    LFVideoDecode *_videoDecode;
    AAPLEAGLLayer *_glLayer;
}

/**
 *  初始化
 *
 *  @return self
 */
-(instancetype)initWitPreview:(UIView *)preview{
    self=[super init];
    if(self){
        _qunue=dispatch_queue_create("LFRtmpServer.Qunue", DISPATCH_QUEUE_SERIAL);
        _semaphore=dispatch_semaphore_create(1);
        _isPlayReady=NO;
        _isSocketConnect=NO;
        _isListenSocket=NO;
        _rtmpChunkFormat=[[LFRtmpChunkFormat alloc] init];
        _createStreamTransactionId=-1;
        _playConfig=[[LFPlayConfig alloc] init];
        _glLayer = [[AAPLEAGLLayer alloc] initWithFrame:preview.bounds];
        [preview.layer addSublayer:_glLayer];
    }
    return self;
}
/**
 *  启动连接
 */
-(void)play{
    __weak __typeof(self)weakSelf = self;
    dispatch_async(_qunue, ^{
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if(![strongSelf connect:_urlParser.domain port:_urlParser.port]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpPlayStatusChange:)]){
                    [strongSelf.delegate onRtmpPlayStatusChange:LFRTMPPlayStatusConnectionFail];
                }
            });
            
        }else{
            _isListenSocket=YES;
            [strongSelf listenSocketRecv];
        }
    });
}

/**
 *  重新连接
 */
-(void)reStart{
    [self closeRtmp];
    [self play];
}
/**
 *  暂停播放
 */
-(void)pause{
    __weak __typeof(self)weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpPlayStatusChange:)]){
            [strongSelf.delegate onRtmpPlayStatusChange:LFRTMPPlayStatusResumeSending];
        }
    });
    NSData *data=[_rtmpChunkFormat pauseChunkFormat:YES milliSeconds:_rtmpChunkFormat.currentTimestamp];
    if(data.length){
        if([self write:(char *)[data bytes] length:(int)data.length isPacket:YES]){
            NSLog(@"--------------RTMP：发送pause成功！--------------");
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpPlayStatusChange:)]){
                    [strongSelf.delegate onRtmpPlayStatusChange:LFRTMPPlayStatusResumeSuccess];
                }
            });
        }else{
            NSLog(@"--------------RTMP：发送pause失败！--------------");
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpPlayStatusChange:)]){
                    [strongSelf.delegate onRtmpPlayStatusChange:LFRTMPPlayStatusResumeFail];
                }
            });
        }
    }
}
/**
 *  继续播放
 */
-(void)resume{
    __weak __typeof(self)weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpPlayStatusChange:)]){
            [strongSelf.delegate onRtmpPlayStatusChange:LFRTMPPlayStatusPauseSending];
        }
    });
    NSData *data=[_rtmpChunkFormat pauseChunkFormat:NO milliSeconds:_rtmpChunkFormat.currentTimestamp];
    if(data.length){
        if([self write:(char *)[data bytes] length:(int)data.length isPacket:YES]){
            NSLog(@"--------------RTMP：发送resume成功！--------------");
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpPlayStatusChange:)]){
                    [strongSelf.delegate onRtmpPlayStatusChange:LFRTMPPlayStatusPauseSuccess];
                }
            });
        }else{
            NSLog(@"--------------RTMP：发送resume失败！--------------");
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpPlayStatusChange:)]){
                    [strongSelf.delegate onRtmpPlayStatusChange:LFRTMPPlayStatusPauseFail];
                }
            });
        }
    }
}
/**
 *  停止play，重置状态，删除推流 关闭socket连接
 */
-(void)stop{
    [self pause];
    [self sendFcUnPublish];
    if(_streamID>0){
        [self sendDeleteStream];
    }
    [self closeRtmp];
}
/**
 *  关闭rtmp资源
 */
-(void)closeRtmp{
    close(_socket);
    _socket=-1;
    _isSocketConnect=NO;
    LFRTMPSERVICE_LOCK
    _isPlayReady=NO;
    _isListenSocket=NO;
    LFRTMPSERVICE_UNLOCK
}
/**
 *  建立连接
 *
 *  @param hostname 主机串
 *  @param port 端口
 *
 *  @return 是否连接成功
 */
-(BOOL)connect:(NSString *)hostname port:(int)port{
    BOOL isConnect=NO;
    if(![self connetSocket:hostname port:port]){
        NSLog(@"--------------RTMP：创建socket通道失败！--------------");
        [self closeRtmp];
    }else{
        if([self handShake]){
            NSLog(@"--------------RTMP：握手成功！--------------");
            if([self sendConnPacket]){
                isConnect=YES;
            }
        }else{
            NSLog(@"--------------RTMP：握手失败！--------------");
            [self closeRtmp];
        }
    }
    return isConnect;
}

/**
 *  建立socket通道 适配ipv6
 *
 *  @param service socket地址信息
 *
 *  @return 是否建立通道成功
 */
-(BOOL)connetSocket:(NSString *)hostname port:(int)port{
    close(_socket);
    _socket=-1;
    NSString *portStr = [NSString stringWithFormat:@"%d", port];
    struct addrinfo hints, *res, *res0;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family   = PF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;
    int gai_error = getaddrinfo([hostname UTF8String], [portStr UTF8String], &hints, &res0);
    if (gai_error){
        NSLog(@"--------------RTMP：获取socket地址失败！--------------");
        _isSocketConnect=NO;
        return _isSocketConnect;
    }
    else{
        NSUInteger capacity = 0;
        for (res = res0; res; res = res->ai_next){
            if (res->ai_family == AF_INET || res->ai_family == AF_INET6) {
                capacity++;
            }
        }
        NSMutableArray *addresses = [NSMutableArray arrayWithCapacity:capacity];
        for (res = res0; res; res = res->ai_next){
            if (res->ai_family == AF_INET){
                NSData *address4 = [NSData dataWithBytes:res->ai_addr length:res->ai_addrlen];
                [addresses addObject:address4];
            }
            else if (res->ai_family == AF_INET6){
                NSData *address6 = [NSData dataWithBytes:res->ai_addr length:res->ai_addrlen];
                [addresses addObject:address6];
            }
        }
        freeaddrinfo(res0);
        if ([addresses count] == 0){
            NSLog(@"--------------RTMP：未获取到socket有效地址！--------------");
            _isSocketConnect=NO;
            return _isSocketConnect;
        }
        NSData *address4 = nil;
        NSData *address6 = nil;
        for (NSData *address in addresses){
            if (!address4 && [self isIPv4Address:address]){
                address4 = address;
            }
            else if (!address6 && [self isIPv6Address:address]){
                address6 = address;
            }
        }
        NSData *address;
        if(address6){
            _socket=socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP);
            address=address6;
        }else if(address4){
            _socket=socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
            address=address4;
        }
        int on=1;
        //初始化socket成功
        if(_socket!=-1){
            //建立连接
            if(connect(_socket,(const struct sockaddr *)[address bytes], (socklen_t)[address length])<0){
                NSLog(@"--------------RTMP：建立socket连接失败！--------------");
                _isSocketConnect=NO;
            }else{
                //设置接收的超时时间
                struct timeval recTimeout = {RTMP_RCVTIMEO,0};
                setsockopt(_socket, SOL_SOCKET, SO_RCVTIMEO, (char *)&recTimeout, sizeof(recTimeout));
                //设置发送超时时间
                struct timeval sendTimeout = {RTMP_SENDTIMEO,0};
                setsockopt(_socket, SOL_SOCKET, SO_SNDTIMEO, (char *)&sendTimeout, sizeof(sendTimeout));
                //tcp下关闭NOSIGPIPE,sockek中有时服务器为了节省资源，在一段时间后会主动关闭连接。
                //前端并不知道这个连接已经断开了，继续通过断开的socket发送消息，会触发SIGPIPE异常导致程序崩溃
                //通过设置忽略SIGPIPE来避免崩溃
                setsockopt(_socket, SOL_SOCKET, SO_NOSIGPIPE, &on, sizeof(on));
                //tcp下关闭NODELAY算法
                setsockopt(_socket, IPPROTO_TCP, TCP_NODELAY, &on, sizeof(on));
                _isSocketConnect=YES;
            }
        }
        return _isSocketConnect;
    }
}
/**
 *  rtmp握手
 */
-(BOOL)handShake{
    BOOL isHandSucc=NO;
    char c0c1[RTMP_HANDSHAKE_BITSIZE+1];
    for(int i=0;i<RTMP_HANDSHAKE_BITSIZE+1;i++){
        //C0是一字节的RTMP协议的版本信息，此信息目前写死为3
        if(i==0){
            c0c1[i]=0x03;
        }
        //C1前四位为时间戳,可以设置为0
        else if(i>0&&i<5){
            c0c1[i]=0x0;
            //C1中间四位全是0，
        }else if(i>4&&i<9){
            c0c1[i]=0x0;
        }else{
            //C1剩余的1528字节为随机数
            c0c1[i]=rand();
        }
    }
    if([self write:c0c1 length:sizeof(c0c1) isPacket:NO]){
        //读取S0S1S2
        LFRTMPReadBuffer *s0s1s2=[LFRTMPReadBuffer new];
        s0s1s2.expectedSize=1;
        if([self read:s0s1s2]){
            NSData *s0=[s0s1s2 getExpectedBuffer:s0s1s2.expectedSize];
            if(s0){
                const char *bytes=[s0 bytes];
                //验证S0;S0是服务器返回的一字节的RTMP协议的版本信息，目前为3
                s0s1s2.expectedSize=RTMP_HANDSHAKE_BITSIZE;
                if(bytes[0]==c0c1[0]&&[self read:s0s1s2]){
                    NSData *s1=[s0s1s2 getExpectedBuffer:s0s1s2.expectedSize];
                    s0s1s2.expectedSize=RTMP_HANDSHAKE_BITSIZE;
                    if(s1&&[self read:s0s1s2]){
                        NSData *s2=[s0s1s2 getExpectedBuffer:s0s1s2.expectedSize];
                        if(s2){
                            //验证S2,S2的数据和C1保持一致，但可能不同的服务器实现不一样
                            BOOL iSCorrect=YES;
                            bytes=[s2 bytes];
                            for(int i=0;i<s2.length;i++){
                                if(bytes[i]!=c0c1[i+1]){
                                    iSCorrect=NO;
                                    break;
                                }
                            }
                            if(iSCorrect){
                                //获取S1
                                bytes=[s1 bytes];
                                //发送C2，C2的数据可和S1保持一致
                                if([self write:bytes length:(int)s1.length isPacket:NO]){
                                    isHandSucc=YES;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return isHandSucc;
}
/**
 *  写数据
 *
 *  @param buffer 待写数据
 *  @param n      待写数据长度
 *
 *  @return 是否写成功
 */
-(BOOL)write:(const char *)dataBytes length:(int)length isPacket:(BOOL)isPacket{
    
    if(isPacket){
        //通过首字节获取header基本信息
        LFRtmpBasicHeader *basicHeader=[LFRtmpBasicHeader basicHeader:dataBytes[0]];
        int rtmpHeaderLength=-1;
        switch (basicHeader.fmtType) {
            case LFRtmpBasicHeaderFmtLarge:
            {
                rtmpHeaderLength=12;
            }
                break;
            case LFRtmpBasicHeaderFmtMedium:
            {
                rtmpHeaderLength=8;
            }
                break;
            case LFRtmpBasicHeaderFmtSmall:
            {
                rtmpHeaderLength=4;
            }
                break;
            default:
                break;
        }
        if(rtmpHeaderLength==-1){
            NSLog(@"--------------RTMP：待发送数据头错误！--------------");
            return NO;
        }
        //有扩展时间戳，则数据头中包含四字节的扩展数据
        if(dataBytes[1]==0x1&&dataBytes[2]==0x1&&dataBytes[3]==0x1){
            rtmpHeaderLength+=4;
        }
        BOOL isWriteSucc=YES;
        int chunkSize=_rtmpChunkFormat.outChunkSize;
        int count=ceil((length-rtmpHeaderLength)/(chunkSize+0.0));
        //拆分数据将大数据拆分为小的chunk块
        for(int i=0;i<count;i++){
            NSMutableData *chunkData=[NSMutableData data];
            if(i==count-1){
                [chunkData setLength:(length-rtmpHeaderLength-i*chunkSize)];
                uint8_t *buffer=[chunkData mutableBytes];
                for(int j=0;j<(length-rtmpHeaderLength-i*chunkSize);j++){
                    buffer[j]=dataBytes[i*chunkSize+j+rtmpHeaderLength];
                }
            }else{
                [chunkData setLength:chunkSize];
                uint8_t *buffer=[chunkData mutableBytes];
                for(int j=0;j<chunkSize;j++){
                    buffer[j]=dataBytes[i*chunkSize+j+rtmpHeaderLength];
                }
            }
            NSMutableData *sendPacketData=[NSMutableData new];
            if(i==0){
                [sendPacketData setLength:rtmpHeaderLength];
                uint8_t *packetBytes=[sendPacketData mutableBytes];
                //设置头数据
                for(int k=0;k<rtmpHeaderLength;k++){
                    packetBytes[k]=dataBytes[k];
                }
                //追加chunk数据
                [sendPacketData appendData:chunkData];
            }else{
                [sendPacketData setLength:1];
                uint8_t *packetBytes=[sendPacketData mutableBytes];
                //加包分隔符，如果在发送大于chunk size的包时如果没有加分隔符或者分隔符不正确
                //则会被服务器将socket的状态设置为EPIPE Broken pipe，导致频繁重连
                packetBytes[0]=[LFRtmpChunkFormat chunkPacketSplitChar:basicHeader.chunkStreamID];
                //追加chunk数据
                [sendPacketData appendData:chunkData];
            }
            NSUInteger n=sendPacketData.length;
            while (n>0) {
                ssize_t bytes=send(_socket, [sendPacketData mutableBytes], n, 0);
                if(bytes<0){
                    //如果是被系统呼叫中断如有电话进来则继续发送
                    if(errno==EINTR){
                        continue;
                    }else{
                        isWriteSucc=NO;
                        break;
                    }
                }else if(bytes==0){
                    break;
                }else{
                    n-=bytes;
                }
            }
            if(!isWriteSucc){
                break;
            }
        }
        return isWriteSucc;
        
    }else{
        BOOL isWriteSucc=YES;
        while (length>0) {
            ssize_t bytes=send(_socket, dataBytes, length, 0);
            if(bytes<0){
                //如果是被系统呼叫中断如有电话进来则继续发送
                if(errno==EINTR){
                    continue;
                }else{
                    isWriteSucc=NO;
                    break;
                }
            }else if(bytes==0){
                break;
            }else{
                length-=bytes;
                dataBytes+=bytes;
            }
        }
        return isWriteSucc;
    }
}
/**
 *  读数据 在执行recv方法时当前线程阻塞，直到读取到数据或者超时
 *
 *  @param readBuf
 *
 *  @return 是否读取成功
 */
-(BOOL)read:(LFRTMPReadBuffer *)readBuf{
    BOOL isReadSucc=YES;
    int n=readBuf.expectedSize;
    ssize_t bytes=0;
    while (n>0) {
        char buffer[n];
        bytes=recv(_socket, buffer, n, 0);
        if(bytes<0){
            //如果是被系统呼叫中断如有电话进来则继续读取
            if(errno==EINTR){
                continue;
            }else if(errno==EWOULDBLOCK||errno==EAGAIN){
                NSLog(@"--------------RTMP：读取数据超时！--------------");
                isReadSucc=NO;
                break;
            }
        }else if(bytes>0){
            [readBuf appendData:[NSData dataWithBytes:buffer length:bytes]];
            n=readBuf.expectedSize-[readBuf size];
        }else{
            NSLog(@"--------------RTMP：未读取到数据！--------------");
            isReadSucc=NO;
            break;
        }
    }
    return isReadSucc;
}
/**
 *  监听socket的响应
 */
-(void)listenSocketRecv{
    LFRTMPReadBuffer *buffer=[LFRTMPReadBuffer new];
    LFRtmpBasicHeader *preBasicHeader=nil;
    while (_isListenSocket) {
        buffer.expectedSize=1;
        if([self read:buffer]){
            NSData *data=[buffer getExpectedBuffer:buffer.expectedSize];
            if(data){
                const char *byte=[data bytes];
                //通过首字节获取header基本信息
                LFRtmpBasicHeader *basicHeader=[LFRtmpBasicHeader basicHeader:byte[0]];
                if(basicHeader){
                    if(preBasicHeader==nil||preBasicHeader.chunkStreamID!=basicHeader.chunkStreamID){
                        preBasicHeader=basicHeader;
                    }
                    switch (basicHeader.fmtType) {
                        case LFRtmpBasicHeaderFmtLarge:
                        {
                            buffer.expectedSize=LFRtmpMessageHeaderSizeLarge;
                        }
                            break;
                        case LFRtmpBasicHeaderFmtMedium:
                        {
                            buffer.expectedSize=LFRtmpMessageHeaderSizeMedium;
                        }
                            break;
                        case LFRtmpBasicHeaderFmtSmall:
                        {
                            buffer.expectedSize=LFRtmpMessageHeaderSizeSmall;
                        }
                            break;
                        default:
                            break;
                    }
                    //获取header的主体信息
                    if([self read:buffer]){
                        data=[buffer getExpectedBuffer:buffer.expectedSize];
                        if(data){
                            switch (basicHeader.fmtType) {
                                case LFRtmpBasicHeaderFmtLarge:
                                {
                                    LFRtmpMessageHeader *msgHeader=[LFRtmpMessageHeader messageHeader:basicHeader.fmtType
                                                                                                 data:data];
                                    //启用扩展时间戳
                                    if(msgHeader.timestamp>=kMessageThreeByteMax){
                                        buffer.expectedSize=4;
                                        if([self read:buffer]){
                                            NSData *extendDate=[buffer getExpectedBuffer:buffer.expectedSize];
                                            if(extendDate){
                                                LFRtmpExtendedTimestamp *extendedTimestamp=[LFRtmpExtendedTimestamp extendedTimestamp:extendDate];
                                                msgHeader.extendTimestamp=extendedTimestamp;
                                            }
                                        }
                                    }
                                    basicHeader.messageHeader=msgHeader;
                                }
                                    break;
                                case LFRtmpBasicHeaderFmtMedium:
                                {
                                    LFRtmpMessageHeader *msgHeader=[LFRtmpMessageHeader messageHeader:basicHeader.fmtType
                                                                                                 data:data];
                                    //启用扩展时间戳
                                    if(msgHeader.timestamp>=kMessageThreeByteMax){
                                        buffer.expectedSize=4;
                                        if([self read:buffer]){
                                            NSData *extendDate=[buffer getExpectedBuffer:buffer.expectedSize];
                                            if(extendDate){
                                                LFRtmpExtendedTimestamp *extendedTimestamp=[LFRtmpExtendedTimestamp extendedTimestamp:extendDate];
                                                msgHeader.extendTimestamp=extendedTimestamp;
                                            }
                                        }
                                    }
                                    //补齐缺失的信息
                                    if(preBasicHeader){
                                        msgHeader.streamID=preBasicHeader.messageHeader.streamID;
                                    }
                                    basicHeader.messageHeader=msgHeader;
                                }
                                    break;
                                case LFRtmpBasicHeaderFmtSmall:
                                {
                                    LFRtmpMessageHeader *msgHeader=[LFRtmpMessageHeader messageHeader:basicHeader.fmtType
                                                                                                 data:data];
                                    //启用扩展时间戳
                                    if(msgHeader.timestamp>=kMessageThreeByteMax){
                                        buffer.expectedSize=4;
                                        if([self read:buffer]){
                                            NSData *extendDate=[buffer getExpectedBuffer:buffer.expectedSize];
                                            if(extendDate){
                                                LFRtmpExtendedTimestamp *extendedTimestamp=[LFRtmpExtendedTimestamp extendedTimestamp:extendDate];
                                                msgHeader.extendTimestamp=extendedTimestamp;
                                            }
                                        }
                                    }
                                    //补齐缺失的信息
                                    if(preBasicHeader){
                                        msgHeader.streamID=preBasicHeader.messageHeader.streamID;
                                        msgHeader.length=preBasicHeader.messageHeader.length;
                                        msgHeader.typeID=preBasicHeader.messageHeader.typeID;
                                    }
                                    basicHeader.messageHeader=msgHeader;
                                }
                                    break;
                                case LFRtmpBasicHeaderFmtMin:
                                {
                                    //和上一个块的message header完全一致
                                    if(preBasicHeader){
                                        basicHeader.messageHeader=preBasicHeader.messageHeader;
                                    }
                                }
                                    break;
                                default:
                                    break;
                            }
                            //读取chunk data数据
                            if(basicHeader.messageHeader.length>0){
                                //获取chunk data 分隔符的数量
                                int chunkPacketSplitNum=ceil(basicHeader.messageHeader.length/_rtmpChunkFormat.inChunkSize);
                                buffer.expectedSize=chunkPacketSplitNum+basicHeader.messageHeader.length;
                                if([self read:buffer]){
                                    NSData *chunk=[buffer getExpectedBuffer:buffer.expectedSize];
                                    const char *chunkBytes=[chunk bytes];
                                    if(chunk){
                                        //如果是命令消息则判断首字节是否是0x2,因为命令消息的前部都是以字符串表示命令名称
                                        //而在AMF0中字符串类型是0x2
                                        if(basicHeader.messageHeader.typeID==LFRtmpCommandMessage){
                                            uint8_t byte=chunkBytes[0];
                                            if(byte!=0x2){
                                                NSLog(@"--------------RTMP：调用listenSocketRecv失败，命令消息的首字节必须为0x2！--------------");
                                            }
                                        }
                                        if(chunk.length<=_rtmpChunkFormat.inChunkSize){
                                            basicHeader.chunkData=[[LFRtmpChunkData alloc] init:chunk];
                                        }else{
                                            NSMutableData *chunkData=[NSMutableData new];
                                            [chunkData setLength:basicHeader.messageHeader.length];
                                            char *bytes=[chunkData mutableBytes];
                                            int offset=0;
                                            for(int i=0,j=0;i<chunk.length;i++){
                                                //如果一个包的大小超过chunk size的大小 则需要添加包分隔符，包分隔符的规则为0xc0|chunk stream ID
                                                //例如如果是协议控制块流则chunk stream ID为0x2，包分隔符=0xc0|0x2=0xc2
                                                //每两个分隔符之前的数据量是chunk size 的大小，而在整个数据包中分隔符的下标位置的规律
                                                //为chunk size，(chunk size)*2+1，(chunk size)*3+2 。。。这个规律
                                                if(i!=(_rtmpChunkFormat.inChunkSize*(offset+1)+offset)){
                                                    bytes[j++]=chunkBytes[i];
                                                }else{
                                                    offset++;
                                                }
                                            }
                                            basicHeader.chunkData=[[LFRtmpChunkData alloc] init:chunkData];
                                        }
                                        [self handChunkData:basicHeader];
                                    }
                                }
                            }
                        }
                    }

                }
            }
        }
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01f]];
    }
}
/**
 *  处理chunk data的数据跳转
 *
 *  @param basicHeader
 */
-(void)handChunkData:(LFRtmpBasicHeader *)basicHeader{
    switch (basicHeader.messageHeader.typeID) {
        case LFRtmpProControlSetChunkSizeMessage:
        {
            _rtmpChunkFormat.inChunkSize=[basicHeader.chunkData parseSetChunkSize];
        }
            break;
        case LFRtmpProControlAbortMessage:
        {
            _rtmpChunkFormat.abortChunkStreamID=[basicHeader.chunkData parseAbortMessage];
        }
            break;
        case LFRtmpProControlAckMessage:
        {
            _rtmpChunkFormat.acknowledgementSeq=[basicHeader.chunkData parseAcknowledgement];
        }
            break;
        case LFRtmpProControlWindowAckSizeMessage:
        {
            _rtmpChunkFormat.windowAckSize=[basicHeader.chunkData parseWindowAckSize];
        }
            break;
        case LFRtmpProControlSetPeerBandWidthMessage:
        {
            NSDictionary *dic=[basicHeader.chunkData parseBandWidth];
            _rtmpChunkFormat.bandWidth=[[dic valueForKey:kBandWidthSize] intValue];
            _rtmpChunkFormat.bandWidthLimiType=[[dic valueForKey:kBandWidthLimitType] charValue];
        }
            break;
        case LFRtmpUserControlMessage:
        {
            _rtmpChunkFormat.isStreamBegin=[basicHeader.chunkData parseUserCtrlStreamBegin];
        }
            break;
        case LFRtmpCommandMessage:
        {
            LFRtmpResponseCommand *command=[basicHeader.chunkData parseCommand];
            if(command.commandType==LFRtmpResponseCommand_Result){
                if(command.optionObject&&command.getOptionObjectDictionary){
                    NSString *code=[command optionObjectValueForKey:@"code"];
                    if([code isEqualToString:kLFRtmpConnectSuccess]){
                        [self sendCreateStream];
                    }
                }
                if(command.optionObject&&[command.optionObject isKindOfClass:[NSNumber class]]){
                    if(command.transactionID==_createStreamTransactionId){
                        _streamID=[(NSNumber *)command.optionObject intValue];
                        [self sendCheckBindWidth];
                        [self getStreamLength];
                        [self playStream];
                        //[self setBufferLength];
                    }
                }
            }else if(command.commandType==LFRtmpResponseCommandOnStatus){
                if(command.optionObject&&command.getOptionObjectDictionary){
                    NSString *code=[command optionObjectValueForKey:@"code"];
                    __weak __typeof(self)weakSelf = self;
                    if([code isEqualToString:kLFRtmpPlayStart]||[code isEqualToString:kLFRtmpPlayReset]){
                        LFRTMPSERVICE_LOCK
                        _isPlayReady=YES;
                        LFRTMPSERVICE_UNLOCK
                        NSLog(@"--------------RTMP：正确响应play命令，播放准备就绪！！--------------");
                        dispatch_async(dispatch_get_main_queue(), ^{
                            __strong __typeof(weakSelf)strongSelf = weakSelf;
                            if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpPlayStatusChange:)]){
                                [strongSelf.delegate onRtmpPlayStatusChange:LFRTMPPlayStatusPlayReady];
                            }
                        });
                    }
                    if([code isEqualToString:kLFRtmpPlayStreamNotFound]){
                        NSLog(@"--------------RTMP：播放失败！要播放的流%@不存在--------------",_urlParser.streamName);
                        LFRTMPSERVICE_LOCK
                        _isListenSocket=NO;
                        LFRTMPSERVICE_UNLOCK
                        dispatch_async(dispatch_get_main_queue(), ^{
                            __strong __typeof(weakSelf)strongSelf = weakSelf;
                            if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpPlayStatusChange:)]){
                                [strongSelf.delegate onRtmpPlayStatusChange:LFRTMPPlayStatusPlayFail];
                            }
                        });
                    }
                }
            }
        }
            break;
        case LFRtmpAudioMessage:
        {
            if(basicHeader.chunkData.data.length>=2){
                const char * bytes=[basicHeader.chunkData.data bytes];
                //音频同步包
                if(bytes[1]==0x0){
                    if([LFAudioDataParser parseAudioSequenceHeader:basicHeader.chunkData.data withConfig:_playConfig]){
                        if(_audioOutputQueue==nil){
                            _audioOutputQueue=[[MCAudioOutputQueue alloc] initWithFormat:[_playConfig getAudioStreamBasicDescription] bufferSize:1024 macgicCookie:nil];
                        }
                    }
                }else{
                    //音频数据包
                    NSUInteger aacDataLength=[LFAudioDataParser parseAudioData:basicHeader.chunkData.data].length;
                    NSMutableData *data=[NSMutableData dataWithData:[_playConfig getAACADTS:aacDataLength]];
                    [data appendData:[LFAudioDataParser parseAudioData:basicHeader.chunkData.data]];
                    if(data.length>0){
                        AudioStreamPacketDescription des={0};
                        des.mDataByteSize=(UInt32)data.length-kLFPlayConfigADTSLength;
                        des.mVariableFramesInPacket=0;
                        des.mStartOffset=kLFPlayConfigADTSLength;
                        [_audioOutputQueue playData:data packetCount:1 packetDescriptions:&des isEof:NO];
                    }
                }
            }
        }
            break;
        case LFRtmpVideoMessage:
        {
            if(basicHeader.chunkData.data.length>=2){
                const char * bytes=[basicHeader.chunkData.data bytes];
                //AVCPacketType 如果是同步包则为0如果是普通数据包则为1
                if(bytes[1]==0x0){
                    if([LFVideoDataParser parseVideoSequenceHeader:basicHeader.chunkData.data withConfig:_playConfig]){

                    }
                }else{
                    if(_videoDecode==nil){
                        _videoDecode=[[LFVideoDecode alloc] init:_playConfig];
                        _videoDecode.delegate=self;
                    }
                    //视频数据包
                    LFVideoPacketData *videoPacket=[LFVideoDataParser parseVideoData:basicHeader.chunkData.data];
                    [_videoDecode decode:videoPacket];                    
                }
            }
        }
            break;
        case LFRtmpDataMessage:
        {
            LFRtmpResponseCommand *command=[basicHeader.chunkData parseCommand];
            if(command.commandType==LFRtmpResponseCommandOnMetaData){
                if(command.allData&&command.allData.count>0&&[[command.allData firstObject] isKindOfClass:[NSDictionary class]]){
                    NSDictionary *playParam=[command.allData firstObject];
                    [_playConfig setValuesForKeysWithDictionary:playParam];
                    NSLog(@"--------------RTMP：成功获取OnMetaData配置播放参数--------------");
                }
            }
        }
            break;
        default:
            break;
    }
}
/**
 *  发送连接请求
 *
 *  @return 是否连接成功
 */
-(BOOL)sendConnPacket{
    NSData *data=[_rtmpChunkFormat connectChunkFormat:_urlParser.appName tcUrl:_urlParser.tcUrl];
    if([self write:(char *)[data bytes] length:(int)data.length isPacket:YES]){
        return YES;
    }else{
        return NO;
    }
}

/**
 *  创建流
 */
-(void)sendCreateStream{
    NSArray *array=[_rtmpChunkFormat createStreamChunkForamt];
    NSData *data=[array firstObject];
    _createStreamTransactionId=[[array lastObject] intValue];
    if(data.length){
        if([self write:(char *)[data bytes] length:(int)data.length isPacket:YES]){
            NSLog(@"--------------RTMP：发送createStream成功！--------------");
        }else{
            NSLog(@"--------------RTMP：发送createStream失败！--------------");
        }
    }
}
/**
 *  发送bindWidth的响应
 */
-(void)sendCheckBindWidth{
    NSData *data=[_rtmpChunkFormat checkbwChunkForamt];
    if(data.length){
        if([self write:(char *)[data bytes] length:(int)data.length isPacket:YES]){
            NSLog(@"--------------RTMP：发送_checkbw成功！--------------");
        }else{
            NSLog(@"--------------RTMP：发送_checkbw失败！--------------");
        }
    }
}
/**
 *  删除流
 */
-(void)sendDeleteStream{
    NSData *data=[_rtmpChunkFormat deleteStreamForamt:_streamID];
    if(data.length){
        if([self write:(char *)[data bytes] length:(int)data.length isPacket:YES]){
            NSLog(@"--------------RTMP：发送deleteStream成功！--------------");
        }else{
            NSLog(@"--------------RTMP：发送deleteStream失败！--------------");
        }
    }
}

/**
 *  fcUnPublish
 */
-(void)sendFcUnPublish{
    
    NSData *data=[_rtmpChunkFormat fcUnPublishStreamChunkFormat:_urlParser.streamName];
    if(data.length){
        if([self write:(char *)[data bytes] length:(int)data.length isPacket:YES]){
            NSLog(@"--------------RTMP：发送fcUnPublish成功！--------------");
        }else{
            NSLog(@"--------------RTMP：发送fcUnPublish失败！--------------");
        }
    }
}
/**
 *  getStreamLength
 */
-(void)getStreamLength{
    
    NSData *data=[_rtmpChunkFormat getStreamLengthChunkFormat:_urlParser.streamName];
    if(data.length){
        if([self write:(char *)[data bytes] length:(int)data.length isPacket:YES]){
            NSLog(@"--------------RTMP：发送getStreamLength成功！--------------");
        }else{
            NSLog(@"--------------RTMP：发送getStreamLength失败！--------------");
        }
    }
}
/**
 *  play
 */
-(void)playStream{
    __weak __typeof(self)weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpPlayStatusChange:)]){
            [strongSelf.delegate onRtmpPlayStatusChange:LFRTMPPlayStatusPlaySending];
        }
    });
    NSData *data=[_rtmpChunkFormat playChunkFormat:_urlParser.streamName];
    if(data.length){
        if([self write:(char *)[data bytes] length:(int)data.length isPacket:YES]){
            NSLog(@"--------------RTMP：发送play成功！--------------");
        }else{
            NSLog(@"--------------RTMP：发送play失败！--------------");
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpPlayStatusChange:)]){
                    [strongSelf.delegate onRtmpPlayStatusChange:LFRTMPPlayStatusPlayFail];
                }
            });
        }
    }
}
/**
 *  setBufferLength
 */
//-(void)setBufferLength{
//    
//    NSData *data=[_rtmpChunkFormat setBufferLengthChunkFormat:_streamID bufferSize:3000];
//    if(data.length){
//        if([self write:(char *)[data bytes] length:(int)data.length isPacket:YES]){
//            NSLog(@"--------------RTMP：发送setBufferLength成功！--------------");
//        }else{
//            NSLog(@"--------------RTMP：发送setBufferLength失败！--------------");
//        }
//    }
//}

#pragma mark ---------LFVideoDecodeDelegate---------
/**
 *  返回解码后的数据
 *  @param playConfig
 *  @return instancetype
 */
-(void)onDidVideoDecodeOutput:(CVPixelBufferRef)pixelBuffer{
    if(pixelBuffer) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            _glLayer.pixelBuffer = pixelBuffer;
        });
        CVPixelBufferRelease(pixelBuffer);
    }
}
#pragma mark private method
/**
 *  是否ipv4的地址
 *
 */
-(BOOL)isIPv4Address:(NSData *)address
{
    if ([address length] >= sizeof(struct sockaddr)){
        const struct sockaddr *sockaddrX = [address bytes];
        if (sockaddrX->sa_family == AF_INET) {
            return YES;
        }
    }
    return NO;
}
/**
 *  是否ipv6的地址
 *
 */
-(BOOL)isIPv6Address:(NSData *)address
{
    if ([address length] >= sizeof(struct sockaddr)){
        const struct sockaddr *sockaddrX = [address bytes];
        if (sockaddrX->sa_family == AF_INET6) {
            return YES;
        }
    }
    return NO;
}

@end
