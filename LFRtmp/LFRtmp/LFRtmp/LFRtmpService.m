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
#define RTMP_BUFFER_SIZE (16*1024)
#define LFRTMPSERVICE_LOCK dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
#define LFRTMPSERVICE_UNLOCK dispatch_semaphore_signal(_semaphore);
#import "LFRtmpService.h"
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <netinet/tcp.h>
#import "LFRtmpChunkFormat.h"
#import "LFRtmpUrlParser.h"
#import "LFMicDevice.h"
#import "LFAACEncode.h"
#import "LFVideoHardEncode.h"
#import "LFVideoSoftEncode.h"
@interface LFRTMPReadBuffer : NSObject
@property (nonatomic,assign)int size;
@property (nonatomic,assign) BOOL isTimeout;
@end

@implementation LFRTMPReadBuffer
{
   char _buffer[RTMP_BUFFER_SIZE];
}
-(char *)getBuffer{
    return _buffer;
}

@end
@interface LFRtmpService()<LFRtmpChunkFormatDelegate,LFMicDeviceDelegate,LFCameraDeviceDelegate,LFVideoEncodeDelegate>
@property (assign,nonatomic) BOOL isSending;
@end
@implementation LFRtmpService
{
    int _socket;//socket通道描述符
    dispatch_queue_t _qunue;
    dispatch_semaphore_t _semaphore;
    LFRtmpUrlParser *_urlParser;
    LFRtmpChunkFormat *_rtmpChunkFormat;
    BOOL _isPublishReady;
    BOOL _isSocketConnect;
    BOOL _isSendFlvAACSequenceHeader;
    BOOL _isSendFlvVideoSequenceHeader;
    int _streamID;
    NSMutableArray *_mediaSendBuffers;
    LFMicDevice *_micDivice;
    LFAACEncode *_aacEncode;
    LFCameraDevice *_cameraDevice;
    id<LFVideoEncodeProtocol> _videoEncode;
}

/**
 *  初始化
 *
 *  @param videoConfig 视频配置信息
 *  @param audioConfig 音频配置信息
 *
 *  @return self
 */
-(instancetype)initWitConfig:(LFVideoConfig *)videoConfig
                 audioConfig:(LFAudioConfig *)audioConfig
                     preview:(UIView *)preview{
    self=[super init];
    if(self){
        _qunue=dispatch_queue_create("LFRtmpServer.Qunue", DISPATCH_QUEUE_SERIAL);
        _semaphore=dispatch_semaphore_create(1);
        _mediaSendBuffers=[NSMutableArray new];
        _isPublishReady=NO;
        _isSocketConnect=NO;
        _isSending=NO;
        _rtmpChunkFormat=[[LFRtmpChunkFormat alloc] init];
        _rtmpChunkFormat.delegate=self;
        _audioConfig=audioConfig;
        _preview=preview;
        [self setVideoConfig:videoConfig];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(chearBuffer)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
    }
    return self;
}
/**
 *  方向
 */
-(void)setOrientation:(UIInterfaceOrientation)orientation{
    _orientation=orientation;
    _cameraDevice.orientation=orientation;
}
/**
 *  是否打开闪光灯
 */
-(void)setIsOpenFlash:(BOOL)isOpenFlash{
    _cameraDevice.isOpenFlash=isOpenFlash;
    _isOpenFlash=isOpenFlash;
}
/**
 *  摄像头选取
 */
-(void)setDevicePosition:(AVCaptureDevicePosition)devicePosition{
    _cameraDevice.devicePosition=devicePosition;
    _devicePosition=devicePosition;
}
/**
 *  配置视频属性
 */
-(void)setVideoConfig:(LFVideoConfig *)videoConfig{
    _videoConfig=videoConfig;
    _isLandscape=videoConfig.isLandscape;
    [self configDevice];
}
/**
 *  焦距调整
 */
-(void)setZoomScale:(CGFloat)zoomScale{
    [_cameraDevice setZoomScale:zoomScale];
    _zoomScale=zoomScale;
}
/**
 *  滤镜 默认使用美颜效果 可使用GPUImage的定义的滤镜效果，也可基于GPUImage实现自定义滤镜
 */
-(void)setFilterType:(LFCameraDeviceFilter)filterType{
    _filterType=filterType;
    [_cameraDevice setFilterType:filterType];
}
/**
 *  水印
 */
-(void)setLogoView:(UIView *)logoView{
    [_cameraDevice setLogoView:logoView];
    _logoView=logoView;
}
/**
 *  启动连接
 *
 *  @param hostname 主机串
 *  @param port 端口
 */
-(void)start:(NSString *)url
        port:(int)port{
    _urlParser=[[LFRtmpUrlParser alloc] initWithUrl:url port:port];
    __weak __typeof(self)weakSelf = self;
    dispatch_async(_qunue, ^{
        while (![self connect:_urlParser.domain port:_urlParser.port]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpStatusChange:)]){
                    [strongSelf.delegate onRtmpStatusChange:LFRTMPStatusConnectionFail];
                }
            });
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01f]];
        }
    });
}

/**
 *  重新连接
 */
-(void)reStart{
    [self closeRtmp];
    [self start:_urlParser.originalUrl port:_urlParser.port];
}
/**
 *  停止推流，重置状态，删除推流 关闭socket连接
 */
-(void)stop{
    [self sendFcUnPublish];
    if(_streamID>0){
        [self sendDeleteStream];
    }
    [self closeRtmp];
}
/**
 *  退出
 */
-(void)quit{
    [self sendFcUnPublish];
    if(_streamID>0){
        [self sendDeleteStream];
    }
    [self closeRtmp];
    [self stopRecord];
}
/**
 *  关闭rtmp资源
 */
-(void)closeRtmp{
    close(_socket);
    _socket=-1;
    _isSocketConnect=NO;
    LFRTMPSERVICE_LOCK
    _isSendFlvAACSequenceHeader=NO;
    _isSendFlvVideoSequenceHeader=NO;
    _isSending=NO;
    _isPublishReady=NO;
    [_mediaSendBuffers removeAllObjects];
    LFRTMPSERVICE_UNLOCK
}
/**
 *  清理待发送数据
 */
-(void)chearBuffer{
    LFRTMPSERVICE_LOCK
    [_mediaSendBuffers removeAllObjects];
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
    char C0C1[RTMP_HANDSHAKE_BITSIZE+1];
    for(int i=0;i<RTMP_HANDSHAKE_BITSIZE+1;i++){
        //C0是一字节的RTMP协议的版本信息，此信息目前写死为3
        if(i==0){
            C0C1[i]=0x03;
        }
        //C1前四位为时间戳,可以设置为0
        else if(i>0&&i<5){
            C0C1[i]=0x0;
            //C1中间四位全是0，
        }else if(i>4&&i<9){
            C0C1[i]=0x0;
        }else{
            //C1剩余的1528字节为随机数
            C0C1[i]=rand();
        }
    }
    if([self write:C0C1 length:sizeof(C0C1)]){
        //读取S0S1S2
         LFRTMPReadBuffer *S0S1S2=[LFRTMPReadBuffer new];
        if([self read:S0S1S2]){
            if(S0S1S2.size==RTMP_HANDSHAKE_BITSIZE*2+1){
                //验证S0;S0是服务器返回的一字节的RTMP协议的版本信息，目前为3
                if([S0S1S2 getBuffer][0]==0x3){
                    //验证S2,S2的数据和C1保持一致，但可能不同的服务器实现不一样
                    BOOL iSCorrect=YES;
                    int flag=1;
                    for(int i=RTMP_HANDSHAKE_BITSIZE+1;i<S0S1S2.size;i++){
                        if([S0S1S2 getBuffer][i]!=C0C1[flag++]){
                            iSCorrect=NO;
                            break;
                        }
                    }
                    if(iSCorrect){
                        //获取S1
                        char S1[RTMP_HANDSHAKE_BITSIZE];
                        for(int i=1;i<RTMP_HANDSHAKE_BITSIZE+1;i++){
                            S1[i-1]=[S0S1S2 getBuffer][i];
                        }
                        //发送C2，C2的数据可和S1保持一致
                        if([self write:S1 length:sizeof(S1)]){
                            isHandSucc=YES;
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
-(BOOL)write:(const char *)buffer length:(int)n{
    BOOL isWriteSucc=YES;
    const char *pBuffer=buffer;
    while (n>0) {
        ssize_t bytes=send(_socket, pBuffer, n, 0);
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
            pBuffer+=bytes;
        }
    }
    return isWriteSucc;
}
/**
 *  写音视频数据
 *
 *  @param buffer 待写数据
 *  @param n      待写数据长度
 *
 *  @return 是否写成功
 */
-(void)writeMediaData{
    if(_mediaSendBuffers.count>0&&_socket!=-1){
        LFRTMPSERVICE_LOCK
        _isSending=YES;
        NSMutableData *data=[_mediaSendBuffers firstObject];
        LFRTMPSERVICE_UNLOCK
        uint8_t *dataBytes=[data mutableBytes];
        uint8_t fmtType=dataBytes[0]>>6;
        int rtmpHeaderLength=-1;
        switch (fmtType) {
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
            NSLog(@"--------------RTMP：待发送音视频数据头错误！--------------");
            return;
        }
        //有扩展时间戳，则数据头中包含四字节的扩展数据
        if(dataBytes[1]==0x1&&dataBytes[2]==0x1&&dataBytes[3]==0x1){
            rtmpHeaderLength+=4;
        }
        BOOL isReConnect=NO;
        int chunkSize=_rtmpChunkFormat.chunkSize;
        int count=ceil((data.length-rtmpHeaderLength)/(chunkSize+0.0));
        //拆分数据将大数据拆分为小的chunk块
        for(int i=0;i<count;i++){
            NSMutableData *chunkData=[NSMutableData data];
            if(i==count-1){
                [chunkData setLength:(data.length-rtmpHeaderLength-i*chunkSize)];
                uint8_t *buffer=[chunkData mutableBytes];
                for(int j=0;j<(data.length-rtmpHeaderLength-i*chunkSize);j++){
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
                packetBytes[0]=[LFRtmpChunkFormat chunkPacketSplitChar:LFRtmpBasicHeaderMediaStreamID];
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
                        isReConnect=YES;
                        break;
                    }
                }else if(bytes==0){
                    break;
                }else{
                    n-=bytes;
                }
            }
            if(isReConnect){
                break;
            }
        }
        LFRTMPSERVICE_LOCK
        if(isReConnect){
            //重连
            [self connetSocket:_urlParser.domain port:_urlParser.port];
        }
        _isSending=NO;
        [_mediaSendBuffers removeObject:data];
        LFRTMPSERVICE_UNLOCK
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
    ssize_t bytes=0;
    while (YES) {
        bytes=recv(_socket, [readBuf getBuffer], RTMP_BUFFER_SIZE, 0);
        if(bytes<0){
            //如果是被系统呼叫中断如有电话进来则继续读取
            if(errno==EINTR){
                continue;
            }else if(errno==EWOULDBLOCK||errno==EAGAIN){
                NSLog(@"--------------RTMP：读取数据超时！--------------");
                readBuf.isTimeout=YES;
                isReadSucc=NO;
                break;
            }
        }else{
            readBuf.size+=(int)bytes;
            break;
        }
    }
    return isReadSucc;
}
/**
 *  发送连接请求
 *
 *  @return 是否连接成功
 */
-(BOOL)sendConnPacket{
    NSData *data=[_rtmpChunkFormat connectChunkFormat:_urlParser.appName tcUrl:_urlParser.tcUrl];
    if([self write:[data bytes] length:(int)data.length]){
        BOOL isHandSucc=YES;
        LFRTMPReadBuffer *buffer=[LFRTMPReadBuffer new];
        if([self read:buffer]){
            [_rtmpChunkFormat parseResponsePacket:[buffer getBuffer]
                                             size:buffer.size
                                      sendCmdType:LFRtmpSendCommandConnect];
        }else{
            isHandSucc=NO;
        }
        return isHandSucc;
    }else{
        return NO;
    }
}

/**
 *  释放流
 */
-(void)sendReleaseStream{
    NSData *data=[_rtmpChunkFormat releaseStreamChunkFormat:_urlParser.streamName];
    if(data.length){
        if([self write:[data bytes] length:(int)data.length]){
            NSLog(@"--------------RTMP：发送sendReleaseStream成功！--------------");
            LFRTMPReadBuffer *buffer=[LFRTMPReadBuffer new];
            if([self read:buffer]){
                NSLog(@"--------------RTMP：获取sendReleaseStream响应成功！--------------");
                [_rtmpChunkFormat parseResponsePacket:[buffer getBuffer]
                                                 size:buffer.size
                                          sendCmdType:LFRtmpSendCommandReleaseStream];
            }else{
                NSLog(@"--------------RTMP：获取sendReleaseStream响应失败！--------------");
            }
        }else{
            NSLog(@"--------------RTMP：发送sendReleaseStream失败！--------------");
        }
    }
}
/**
 *  取消推流
 */
-(void)sendFCPublish{
    NSData *data=[_rtmpChunkFormat fcPublishStreamChunkFormat:_urlParser.streamName];
    if(data.length){
        if([self write:[data bytes] length:(int)data.length]){
            NSLog(@"--------------RTMP：发送FCPublish成功！--------------");
            LFRTMPReadBuffer *buffer=[LFRTMPReadBuffer new];
            if([self read:buffer]){
                NSLog(@"--------------RTMP：获取FCPublish响应成功！--------------");
                [_rtmpChunkFormat parseResponsePacket:[buffer getBuffer]
                                                 size:buffer.size
                                          sendCmdType:LFRtmpSendCommandFCPublish];
            }else{
                NSLog(@"--------------RTMP：获取FCPublish响应失败！--------------");
            }
        }else{
            NSLog(@"--------------RTMP：发送FCPublish失败！--------------");
        }
    }
}
/**
 *  创建流
 */
-(void)sendCreateStream{
    NSData *data=[_rtmpChunkFormat createStreamChunkForamt];
    if(data.length){
        if([self write:[data bytes] length:(int)data.length]){
            NSLog(@"--------------RTMP：发送createStream成功！--------------");
            LFRTMPReadBuffer *buffer=[LFRTMPReadBuffer new];
            if([self read:buffer]){
                NSLog(@"--------------RTMP：获取createStream响应成功！--------------");
                [_rtmpChunkFormat parseResponsePacket:[buffer getBuffer]
                                                 size:buffer.size
                                          sendCmdType:LFRtmpSendCommandCreateStream];
            }else{
                NSLog(@"--------------RTMP：获取createStream响应失败！--------------");
            }
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
        if([self write:[data bytes] length:(int)data.length]){
            NSLog(@"--------------RTMP：发送_checkbw成功！--------------");
            LFRTMPReadBuffer *buffer=[LFRTMPReadBuffer new];
            if([self read:buffer]){
                NSLog(@"--------------RTMP：获取_checkbw响应成功！--------------");
                [_rtmpChunkFormat parseResponsePacket:[buffer getBuffer]
                                                 size:buffer.size
                                          sendCmdType:LFRtmpSendCommand_Checkbw];
            }else{
                NSLog(@"--------------RTMP：获取_checkbw响应失败！--------------");
            }
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
        if([self write:[data bytes] length:(int)data.length]){
            NSLog(@"--------------RTMP：发送deleteStream成功！--------------");
            LFRTMPReadBuffer *buffer=[LFRTMPReadBuffer new];
            if([self read:buffer]){
                NSLog(@"--------------RTMP：获取deleteStream响应成功！--------------");
                [_rtmpChunkFormat parseResponsePacket:[buffer getBuffer]
                                                 size:buffer.size
                                          sendCmdType:LFRtmpSendCommandDeleteStream];
            }else{
                NSLog(@"--------------RTMP：获取deleteStream响应失败！--------------");
            }
        }else{
            NSLog(@"--------------RTMP：发送deleteStream失败！--------------");
        }
    }
}
/**
 *  推流
 */
-(void)sendPublishStream{
    __weak __typeof(self)weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpStatusChange:)]){
            [strongSelf.delegate onRtmpStatusChange:LFRTMPStatusPublishSending];
        }
    });
    NSData *data=[_rtmpChunkFormat publishStreamChunkFormat:_urlParser.streamName];
    if(data.length){
        if([self write:[data bytes] length:(int)data.length]){
            NSLog(@"--------------RTMP：发送publish成功！--------------");
            LFRTMPReadBuffer *buffer=[LFRTMPReadBuffer new];
            if([self read:buffer]){
                NSLog(@"--------------RTMP：获取publish响应成功！--------------");
                [_rtmpChunkFormat parseResponsePacket:[buffer getBuffer]
                                                 size:buffer.size
                                          sendCmdType:LFRtmpSendCommandPublishStream];
            }else{
                NSLog(@"--------------RTMP：获取publish响应失败！--------------");
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpStatusChange:)]){
                        [strongSelf.delegate onRtmpStatusChange:LFRTMPStatusPublishFail];
                    }
                });
            }
        }else{
            NSLog(@"--------------RTMP：发送publish失败！--------------");
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpStatusChange:)]){
                    [strongSelf.delegate onRtmpStatusChange:LFRTMPStatusPublishFail];
                }
            });
        }
    }
}
/**
 *  fcUnPublish
 */
-(void)sendFcUnPublish{
    
    NSData *data=[_rtmpChunkFormat fcUnPublishStreamChunkFormat:_urlParser.streamName];
    if(data.length){
        if([self write:[data bytes] length:(int)data.length]){
            NSLog(@"--------------RTMP：发送fcUnPublish成功！--------------");
            LFRTMPReadBuffer *buffer=[LFRTMPReadBuffer new];
            if([self read:buffer]){
                NSLog(@"--------------RTMP：获取fcUnPublish响应成功！--------------");
                [_rtmpChunkFormat parseResponsePacket:[buffer getBuffer]
                                                 size:buffer.size
                                          sendCmdType:LFRtmpSendCommandFCUnPublishStream];
            }else{
                NSLog(@"--------------RTMP：获取fcUnPublish响应失败！--------------");
            }
        }else{
            NSLog(@"--------------RTMP：发送fcUnPublish失败！--------------");
        }
    }
}
/**
 *  发送音频数据包
 */
-(void)sendAudioPacket:(NSData *)data{
    if(!_isSendFlvAACSequenceHeader){
        LFRTMPSERVICE_LOCK
        [_mediaSendBuffers addObject:[_rtmpChunkFormat flvAACSequenceHeader]];
        _isSendFlvAACSequenceHeader=YES;
        LFRTMPSERVICE_UNLOCK
        if(!_isSending){
            [self writeMediaData];
        }
    }
    LFRTMPSERVICE_LOCK
    [_mediaSendBuffers addObject:[_rtmpChunkFormat flvAACAudioData:data]];
    LFRTMPSERVICE_UNLOCK
    if(!_isSending){
        [self writeMediaData];
    }
}
/**
 *  发送音频数据包
 */
-(void)sendVideoPacket:(LFVideoEncodeInfo *)info{
    if(!_isSendFlvVideoSequenceHeader){
        LFRTMPSERVICE_LOCK
        [_mediaSendBuffers addObject:[_rtmpChunkFormat flvVideoSequenceHeader:info]];
        _isSendFlvVideoSequenceHeader=YES;
        LFRTMPSERVICE_UNLOCK
        if(!_isSending){
            [self writeMediaData];
        }
    }
    LFRTMPSERVICE_LOCK
    [_mediaSendBuffers addObject:[_rtmpChunkFormat flvVideoData:info]];
    LFRTMPSERVICE_UNLOCK
    if(!_isSending){
        [self writeMediaData];
    }
}

#pragma mark LFRtmpChunkFormatDelegate
/**
 *  处理命令消息
 */
-(void)onHandleCommand:(LFRtmpResponseCommand *)command sendCmdType:(LFRtmpSendCommandType)sendCmdType{
    switch (sendCmdType) {
        case LFRtmpSendCommandConnect:
        {
            //处理connect的响应_result
            if(command.commandType==LFRtmpResponseCommand_Result){
                if(command.optionObject&&command.getOptionObjectDictionary){
                    NSString *code=[command optionObjectValueForKey:@"code"];
                    if([code isEqualToString:kLFRtmpConnectSuccess]){
                        [self sendReleaseStream];
                        [self sendFCPublish];
                        [self sendCreateStream];
                    }
                }
           //处理connect的响应onBWDone
            }else if(command.commandType==LFRtmpResponseCommandOnBWDone){
                [self sendCheckBindWidth];
            }
        }
            break;
       case LFRtmpSendCommand_Checkbw:
        {
            if(command.commandType==LFRtmpResponseCommand_Result){
                [self sendPublishStream];
            }
        }
            break;
       case LFRtmpSendCommandCreateStream:
        {
            //处理createStream的响应_result
            if(command.commandType==LFRtmpResponseCommand_Result){
                if(command.optionObject&&[command.optionObject isKindOfClass:[NSNumber class]]){
                    _streamID=[(NSNumber *)command.optionObject intValue];
                }else{
                    NSLog(@"--------------RTMP：解析createStream响应失败！未能获取streamID--------------");
                    [self reStart];
                }
            }
        }
            break;
        case LFRtmpSendCommandPublishStream:
        {
            if(command.commandType==LFRtmpResponseCommandOnStatus){
                if(command.optionObject&&command.getOptionObjectDictionary){
                    NSString *code=[command optionObjectValueForKey:@"code"];
                    __weak __typeof(self)weakSelf = self;
                    if([code isEqualToString:kLFRtmpPublishStart]){
                        LFRTMPSERVICE_LOCK
                        _isPublishReady=YES;
                        LFRTMPSERVICE_UNLOCK
                        NSLog(@"--------------RTMP：解析publish响应成功！推流准备就绪！！--------------");
                        dispatch_async(dispatch_get_main_queue(), ^{
                            __strong __typeof(weakSelf)strongSelf = weakSelf;
                            if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpStatusChange:)]){
                                [strongSelf.delegate onRtmpStatusChange:LFRTMPStatusPublishReady];
                            }
                        });
                    }else{
                        NSLog(@"--------------RTMP：解析publish响应失败！--------------");
                        LFRTMPSERVICE_LOCK
                        _isPublishReady=NO;
                        LFRTMPSERVICE_UNLOCK
                        dispatch_async(dispatch_get_main_queue(), ^{
                            __strong __typeof(weakSelf)strongSelf = weakSelf;
                            if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpStatusChange:)]){
                                [strongSelf.delegate onRtmpStatusChange:LFRTMPStatusPublishFail];
                            }
                        });
                    }
                }else{
                    NSLog(@"--------------RTMP：解析publish响应失败！--------------");
                    LFRTMPSERVICE_LOCK
                    _isPublishReady=NO;
                    LFRTMPSERVICE_UNLOCK
                }
            }
        }
            break;
        default:
            break;
    }
}

#pragma mark device
/**
 *  配置设备
 */
-(void)configDevice{
    //配置音频
    if(_micDivice){
        [_micDivice stopOutput];
    }
    _micDivice=[[LFMicDevice alloc] init:_audioConfig];
    _micDivice.delegate=self;
    //配置AAC编码器
    _aacEncode=[[LFAACEncode alloc] init:_audioConfig];
    //配置视频
    if(_cameraDevice){
        [_cameraDevice stopOutput];
    }
    _cameraDevice=[[LFCameraDevice alloc] init:_videoConfig];
    _cameraDevice.orientation=(_orientation==UIInterfaceOrientationUnknown?UIInterfaceOrientationPortrait:_orientation);
    [_cameraDevice setPreview:_preview];
    _cameraDevice.delegate=self;
    //配置视频编码器
    if(_videoEncode){
        [_videoEncode stopEncode];
    }
    if([[UIDevice currentDevice].systemVersion floatValue] < 8.0){
        _videoEncode=[[LFVideoSoftEncode alloc] init:_videoConfig];
    }else{
        //ios8以后使用VideoToolbox实现硬编码
        _videoEncode=[[LFVideoHardEncode alloc] init:_videoConfig];
    }
    [_videoEncode setDelegate:self];
    [self startRecord];
}

/**
 *  启动采集
 */
-(void)startRecord{
    [_micDivice startOuput];
    [_cameraDevice startOuput];
}
/**
 *  停止采集
 */
-(void)stopRecord{
    [_micDivice stopOutput];
    [_cameraDevice stopOutput];
}
#pragma mark LFMicDeviceDelegate
/**
 *  音频采集到的PCM数据输出
 */
-(void)onMicOutputData:(AudioBufferList)audioBufferList{
    if(_isPublishReady&&_isSocketConnect){
        //AAC编码
        NSData *data=[_aacEncode encode:audioBufferList];
        __weak __typeof(self)weakSelf = self;
        dispatch_async(_qunue, ^{
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            [strongSelf sendAudioPacket:data];
        });
    }
}
#pragma mark LFCameraDeviceDelegate
/**
 *  摄像头采集到的数据输出
 */
-(void)onCameraOutputData:(CVImageBufferRef)buffer{
    if(_isPublishReady&&_isSocketConnect){
        [_videoEncode encode:buffer timeStamp:[_rtmpChunkFormat currentTimestamp]];
    }
}
#pragma mark LFVideoEncodeDelegate
-(void)onDidVideoEncodeOutput:(LFVideoEncodeInfo *)info{
    if(_isPublishReady&&_isSocketConnect){
        __weak __typeof(self)weakSelf = self;
        dispatch_async(_qunue, ^{
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            [strongSelf sendVideoPacket:info];
        });
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
-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidReceiveMemoryWarningNotification
                                                  object:nil];
    
}
@end
