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
#import "LFRTMPReadBuffer.h"
@interface LFRtmpService()<LFMicDeviceDelegate,LFCameraDeviceDelegate,LFVideoEncodeDelegate>
@property (assign,nonatomic) BOOL isSending;
@end
@implementation LFRtmpService
{
    int _socket;//socket通道描述符
    dispatch_queue_t _qunue;
    dispatch_semaphore_t _semaphore;
    LFRtmpChunkFormat *_rtmpChunkFormat;
    BOOL _isImmediatelyQuitListen;
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
    int _createStreamTransactionId;//createStream对应的事务id
}
+ (id)sharedInstance{
    static LFRtmpService *instance=nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LFRtmpService alloc] init];
    });
    return instance;
}
/**
 *  初始化
 *
 *  @param videoConfig 视频配置信息
 *  @param audioConfig 音频配置信息
 *
 *  @return self
 */
-(void)setupWithVideoConfig:(LFVideoConfig *)videoConfig
                audioConfig:(LFAudioConfig *)audioConfig
                    preview:(UIView *)preview{
    if(!_qunue){
        _qunue=dispatch_queue_create("LFRtmpServer.Qunue", DISPATCH_QUEUE_SERIAL);
        _semaphore=dispatch_semaphore_create(1);
    }
    if(_mediaSendBuffers){
        [_mediaSendBuffers removeAllObjects];
    }else{
        _mediaSendBuffers=[NSMutableArray new];
    }
    _isPublishReady=NO;
    _isSocketConnect=NO;
    _isSending=NO;
    _rtmpChunkFormat=[[LFRtmpChunkFormat alloc] init];
    _audioConfig=audioConfig;
    _preview=preview;
    [self setVideoConfig:videoConfig];
    _createStreamTransactionId=-1;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(clearBuffer)
                                                 name:UIApplicationDidReceiveMemoryWarningNotification
                                               object:nil];
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
-(void)setVideoZoomScale:(CGFloat)zoomScale andError:(void (^)())errorBlock{
    [_cameraDevice setVideoZoomScale:zoomScale andError:^{
        if(errorBlock){
            errorBlock();
        }
    } andfinish:^{
        _zoomScale=zoomScale;
    }];
}
/**
 *  手动对焦
 *
 *  @param point 焦点位置
 */
-(void)setFocusPoint:(CGPoint)point{
    [_cameraDevice setFocusPoint:point];
}
/**
 *  设置对焦模式
 *
 *  @param focusMode 对焦模式，默认系统采用系统设备采用的是持续自动对焦模型AVCaptureFocusModeContinuousAutoFocus
 */
-(void)setFocusMode:(AVCaptureFocusMode)focusMode{
    [_cameraDevice setFocusMode:focusMode];
}
/**
 *  当前摄像头是否支持手动对焦
 */
-(BOOL)isSupportFocusPoint{
    return [_cameraDevice isSupportFocusPoint];
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
 */
-(void)start{
    __weak __typeof(self)weakSelf = self;
    dispatch_async(_qunue, ^{
        __strong __typeof(weakSelf)strongSelf = weakSelf;
         if(![strongSelf connect:_urlParser.domain port:_urlParser.port]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpStatusChange:message:)]){
                    [strongSelf.delegate onRtmpStatusChange:LFRTMPStatusConnectionFail message:nil];
                }
            });
         }else{
            [strongSelf listenSocketRecv];
         }
    });
}

/**
 *  重新连接
 */
-(void)reStart{
    __weak __typeof(self)weakSelf = self;
    dispatch_async(_qunue, ^{
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        [strongSelf closeRtmp];
    });
    [self start];
}
/**
 *  停止推流，重置状态，删除推流 关闭socket连接
 */
-(void)stop{
    __weak __typeof(self)weakSelf = self;
    dispatch_async(_qunue, ^{
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if(_isPublishReady){
            [strongSelf sendFcUnPublish];
        }
        if(_streamID>0){
            [strongSelf sendDeleteStream];
        }
        [strongSelf closeRtmp];
    });
    
}
/**
 *  退出
 */
-(void)quit{
    __weak __typeof(self)weakSelf = self;
    dispatch_async(_qunue, ^{
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if(_isPublishReady){
            [strongSelf sendFcUnPublish];
        }
        if(_streamID>0){
            [strongSelf sendDeleteStream];
        }
        [strongSelf closeRtmp];
        [strongSelf stopRecord];
        [strongSelf resetProperty];
    });
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
/***
 *  重置属性
 */
-(void)resetProperty{
    _cameraDevice.orientation=UIInterfaceOrientationUnknown;
    _logoView=nil;
    _filterType=LFCameraDeviceFilter_Original;
    _zoomScale=0;
    _devicePosition=AVCaptureDevicePositionUnspecified;
    _isOpenFlash=NO;
}
/**
 *  清理待发送数据
 */
-(void)clearBuffer{
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
    _isSocketConnect=NO;
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
            NSLog(@"--------------RTMP：待发送音视频数据头错误！--------------");
            return;
        }
        //有扩展时间戳，则数据头中包含四字节的扩展数据
        if(dataBytes[1]==0x1&&dataBytes[2]==0x1&&dataBytes[3]==0x1){
            rtmpHeaderLength+=4;
        }
        BOOL isReConnect=NO;
        int chunkSize=_rtmpChunkFormat.outChunkSize;
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
            [self reStart];
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
        }else if(bytes==0){
            NSLog(@"--------------RTMP：未读取到任何数据！--------------");
            break;
        }else{
            [readBuf appendData:[NSData dataWithBytes:buffer length:bytes]];
            n=readBuf.expectedSize-[readBuf size];
        }
    }
    return isReadSucc;
}
/**
 *  监听socket的响应直到可以推流为止
 */
-(void)listenSocketRecv{
    LFRTMPReadBuffer *buffer=[LFRTMPReadBuffer new];
    LFRtmpBasicHeader *preBasicHeader=nil;
    _isImmediatelyQuitListen=NO;
    while (!_isPublishReady&&!_isImmediatelyQuitListen) {
        buffer.expectedSize=1;
        if([self read:buffer]){
            BOOL isParseSuccess=YES;
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
                    if([self read:buffer]){
                        //获取header的主体信息
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
                                            }else{
                                                isParseSuccess=NO;
                                            }
                                        }else{
                                            isParseSuccess=NO;
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
                                            }else{
                                                isParseSuccess=NO;
                                            }
                                        }else{
                                            isParseSuccess=NO;
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
                                            }else{
                                                isParseSuccess=NO;
                                            }
                                        }else{
                                            isParseSuccess=NO;
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
                                int chunkPacketSplitNum=ceil(basicHeader.messageHeader.length/[_rtmpChunkFormat inChunkSize]);
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
                                                isParseSuccess=NO;
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
                                    }else{
                                        isParseSuccess=NO;
                                    }
                                }else{
                                    isParseSuccess=NO;
                                }
                            }
                        }else{
                            isParseSuccess=NO;
                        }

                    }else{
                        isParseSuccess=NO;
                    }
                }else{
                    isParseSuccess=NO;
                }
            }
            if(!isParseSuccess){
                break;
            }
        }else{
            break;
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
                        [self sendReleaseStream];
                        [self sendFCPublish];
                        [self sendCreateStream];
                        [self sendCheckBindWidth];
                    }
                }
                if(command.transactionID==_createStreamTransactionId&&command.optionObject&&[command.optionObject isKindOfClass:[NSNumber class]]){
                    _streamID=[(NSNumber *)command.optionObject intValue];
                    [self sendPublishStream];
                }
            }else if(command.commandType==LFRtmpResponseCommandOnStatus){
                if(command.optionObject&&command.getOptionObjectDictionary){
                    NSString *code=[command optionObjectValueForKey:@"code"];
                    __weak __typeof(self)weakSelf = self;
                    if([code isEqualToString:kLFRtmpPublishStart]){
                        [self sendSetDataFrame];
                        LFRTMPSERVICE_LOCK
                        _isPublishReady=YES;
                        LFRTMPSERVICE_UNLOCK
                        NSLog(@"--------------RTMP：解析publish响应成功！推流准备就绪！！--------------");
                        dispatch_async(dispatch_get_main_queue(), ^{
                            __strong __typeof(weakSelf)strongSelf = weakSelf;
                            if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpStatusChange:message:)]){
                                [strongSelf.delegate onRtmpStatusChange:LFRTMPStatusPublishReady message:nil];
                            }
                        });
                    }else{
                        NSLog(@"--------------RTMP：publish响应异常！--------------");
                        LFRTMPSERVICE_LOCK
                        _isPublishReady=NO;
                        _isImmediatelyQuitListen=YES;
                        LFRTMPSERVICE_UNLOCK
                        dispatch_async(dispatch_get_main_queue(), ^{
                            __strong __typeof(weakSelf)strongSelf = weakSelf;
                            if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpStatusChange:message:)]){
                                NSString *code=[command optionObjectValueForKey:@"code"];
                                if([code isEqualToString:kLFRtmpPublishBadName]){
                                    [strongSelf.delegate onRtmpStatusChange:LFRTMPStatusPublishFailBadName
                                                                    message:[command allData]];
                                }else{
                                    [strongSelf.delegate onRtmpStatusChange:LFRTMPStatusPublishFail
                                                                    message:[command allData]];
                                }
                            }
                        });
                    }
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
 *  释放流
 */
-(void)sendReleaseStream{
    NSData *data=[_rtmpChunkFormat releaseStreamChunkFormat:_urlParser.streamName];
    if(data.length){
        if([self write:(char *)[data bytes] length:(int)data.length isPacket:YES]){
            NSLog(@"--------------RTMP：发送sendReleaseStream成功！--------------");
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
        if([self write:(char *)[data bytes] length:(int)data.length isPacket:YES]){
            NSLog(@"--------------RTMP：发送FCPublish成功！--------------");
        }else{
            NSLog(@"--------------RTMP：发送FCPublish失败！--------------");
        }
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
 *  推流
 */
-(void)sendPublishStream{
    __weak __typeof(self)weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpStatusChange:message:)]){
            [strongSelf.delegate onRtmpStatusChange:LFRTMPStatusPublishSending message:nil];
        }
    });
    NSData *data=[_rtmpChunkFormat publishStreamChunkFormat:_urlParser.streamName];
    if(data.length){
        if([self write:(char *)[data bytes] length:(int)data.length isPacket:YES]){
            NSLog(@"--------------RTMP：发送publish成功！--------------");
        }else{
            NSLog(@"--------------RTMP：发送publish失败！--------------");
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                if(strongSelf.delegate&&[strongSelf.delegate respondsToSelector:@selector(onRtmpStatusChange:message:)]){
                    [strongSelf.delegate onRtmpStatusChange:LFRTMPStatusPublishFail message:nil];
                }
            });
        }
    }
}
/**
 *  发送元数据
 */
-(void)sendSetDataFrame{
    NSData *data=[_rtmpChunkFormat setDataFrameChunkFormat:_videoConfig
                                               audioConfig:_audioConfig];
    if(data.length){
        if([self write:(char *)[data bytes] length:(int)data.length isPacket:YES]){
            NSLog(@"--------------RTMP：发送元数据metadata成功！--------------");
        }else{
            NSLog(@"--------------RTMP：发送元数据metadata失败！--------------");
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
 *  发送视频数据包
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
#pragma mark device
/**
 *  配置设备
 */
-(void)configDevice{
    //配置音频
    if(_micDivice){
        [_micDivice stopOutput];
        _micDivice.delegate=nil;
    }
    _micDivice=[[LFMicDevice alloc] init:_audioConfig];
    _micDivice.delegate=self;
    //配置AAC编码器
    _aacEncode=[[LFAACEncode alloc] init:_audioConfig];
    //配置视频
    if(_cameraDevice){
        [_cameraDevice stopOutput];
        _cameraDevice.delegate=nil;
    }
    _cameraDevice=[[LFCameraDevice alloc] init:_videoConfig];
    _cameraDevice.orientation=(_orientation==UIInterfaceOrientationUnknown?UIInterfaceOrientationPortrait:_orientation);
    if(_logoView){
        [_cameraDevice setLogoView:_logoView];
    }
    if(_filterType){
        [_cameraDevice setFilterType:_filterType];
    }
    if(_zoomScale){
        [_cameraDevice setVideoZoomScale:_zoomScale andError:nil andfinish:nil];
    }
    if(_devicePosition){
        [_cameraDevice setDevicePosition:_devicePosition];
    }
    if(_isOpenFlash){
        [_cameraDevice setIsOpenFlash:_isOpenFlash];
    }
    
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
