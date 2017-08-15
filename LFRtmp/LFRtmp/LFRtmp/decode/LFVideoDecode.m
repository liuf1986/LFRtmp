//
//  LFVideoDecode.m
//  LFRtmp
//
//  Created by liuf on 2017/6/9.
//  Copyright © 2017年 liufang. All rights reserved.
//

#import "LFVideoDecode.h"
@implementation LFVideoDecode
{
    VTDecompressionSessionRef _deocderSession;
    CMVideoFormatDescriptionRef _decoderFormatDescription;
    LFPlayConfig *_playConfig;
//    NSFileHandle *_fileHandle;
}
/**
 *  初始化
 *  @param playConfig
 *  @return instancetype
 */
-(instancetype)init:(LFPlayConfig *)playConfig{
    if(self=[super init]){
        _playConfig=playConfig;
//        NSFileManager *fileManager = [NSFileManager defaultManager];
//        NSArray *directoryPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
//        NSString *documentsDirectoryPath = [directoryPaths objectAtIndex:0];
//        NSString *filePath=[NSString stringWithFormat:@"%@/t.h264", documentsDirectoryPath];
//        if ([fileManager fileExistsAtPath:filePath]) {
//            [fileManager removeItemAtPath:filePath error:nil];
//        }
//        [fileManager createFileAtPath:filePath contents:[NSData new] attributes:nil];
//        _fileHandle=[NSFileHandle fileHandleForWritingAtPath:filePath];
    }
    return self;
}
/**
 *  设置解码器
 *  @return 是否初始化成功
 */
-(BOOL)setupDecoder {
    if(_deocderSession) {
        return YES;
    }
    const uint8_t* const parameterSetPointers[2] = {_playConfig.sps.mutableBytes,_playConfig.pps.mutableBytes };
    const size_t parameterSetSizes[2] = {_playConfig.sps.length,_playConfig.pps.length};
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2, //param count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4, //nal start code size
                                                                          &_decoderFormatDescription);
    
    if(status == noErr) {
        CFDictionaryRef attrs = NULL;
        const void *keys[] = { kCVPixelBufferPixelFormatTypeKey };
        uint32_t v = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
        const void *values[] = { CFNumberCreate(NULL, kCFNumberSInt32Type, &v) };
        attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
        VTDecompressionOutputCallbackRecord callBackRecord;
        callBackRecord.decompressionOutputCallback = didDecompress;
        callBackRecord.decompressionOutputRefCon = (__bridge void *)self;
        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                              _decoderFormatDescription,
                                              NULL, attrs,
                                              &callBackRecord,
                                              &_deocderSession);
        CFRelease(attrs);
        return YES;
    } else {
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                             code:status
                                         userInfo:nil];
        NSLog(@"-------------视频解码器初始化失败：%@！------------- ", [error description]);
        return NO;
    }
}
static void didDecompress( void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration ){
    
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
//    LFVideoDecode *decoder = (__bridge LFVideoDecode *)decompressionOutputRefCon;
//    if (decoder.delegate!=nil&&outputPixelBuffer!=NULL&&status==noErr){
//        [decoder.delegate onDidVideoDecodeOutput:*outputPixelBuffer];
//    }
}
/**
 *  解码
 *  @param videoPacket 音频数据
 *  @return CVPixelBufferRef
 */
-(void)decode:(LFVideoPacketData *)videoPacket{
    NSMutableData *mData=[NSMutableData new];
    [videoPacket.datas enumerateObjectsUsingBlock:^(NSMutableData *data, NSUInteger idx, BOOL * _Nonnull stop) {
        uint8_t *bytes=data.mutableBytes;
        int nalType = bytes[4] & 0x1F;
        NSLog(@"naltype:%d",nalType);
        switch (nalType) {
            case 0x05://Nal type is IDR frame
            {
                [mData appendData:data];
            }
                break;
//            case 0x06:
//                break;
            case 0x07://sps数据，在rtmp的流中不一定存在
            {
                NSInteger spsSize = data.length - 4;
                uint8_t *sps = malloc(spsSize);
                memcpy(sps, data.mutableBytes + 4, spsSize);
                _playConfig.sps=[NSMutableData dataWithBytes:sps length:spsSize];
            }
                break;
            case 0x08://PPS数据，在rtmp的流中不一定存在
            {
                NSInteger ppsSize = data.length - 4;
                uint8_t *pps = malloc(ppsSize);
                memcpy(pps, data.mutableBytes + 4, ppsSize);
                _playConfig.pps=[NSMutableData dataWithBytes:pps length:ppsSize];
            }
                break;
//            case 0x01:
//            {
//                [mData appendData:data];
//            }
//                break;
            default://B帧和P帧数据
            {
                [mData appendData:data];

            }
                break;
        }

    }];
    CVPixelBufferRef pixelBuffer = NULL;
    if([self setupDecoder]){
        pixelBuffer=[self decodeNALU:mData];
    }
    if(pixelBuffer!=NULL&&self.delegate){
        [self.delegate onDidVideoDecodeOutput:pixelBuffer];
    }
    
    //        NSMutableData *wData=[NSMutableData dataWithData:data];
    //        uint8_t *wbytes=wData.mutableBytes;
    //        wbytes[0]=0x0;
    //        wbytes[1]=0x0;
    //        wbytes[2]=0x0;
    //        wbytes[3]=0x1;
    //        if(nalType==5){
    //            NSMutableData *sps=[NSMutableData new];
    //            [sps setLength:4];
    //            uint8_t *spsbytes=sps.mutableBytes;
    //            spsbytes[0]=0x0;
    //            spsbytes[1]=0x0;
    //            spsbytes[2]=0x0;
    //            spsbytes[3]=0x1;
    //            [sps appendData:_playConfig.sps];
    //            [_fileHandle writeData:sps];
    //
    //            NSMutableData *pps=[NSMutableData new];
    //            [pps setLength:4];
    //            uint8_t *ppsbytes=pps.mutableBytes;
    //            ppsbytes[0]=0x0;
    //            ppsbytes[1]=0x0;
    //            ppsbytes[2]=0x0;
    //            ppsbytes[3]=0x1;
    //            [pps appendData:_playConfig.pps];
    //            [_fileHandle writeData:pps];
    //            
    //        }
    //        [_fileHandle writeData:wData];
    
}
-(CVPixelBufferRef)decodeNALU:(NSData *)data {
    CVPixelBufferRef outputPixelBuffer = NULL;
    if(_deocderSession){
        CMBlockBufferRef blockBuffer = NULL;
        OSStatus status  = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                              (void *)data.bytes, data.length,
                                                              kCFAllocatorNull,
                                                              NULL, 0, data.length,
                                                              0, &blockBuffer);
        if(status == kCMBlockBufferNoErr) {
            CMSampleBufferRef sampleBuffer = NULL;
            const size_t sampleSizeArray[] = {data.length};
            status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                               blockBuffer,
                                               _decoderFormatDescription ,
                                               1, 0, NULL, 1, sampleSizeArray,
                                               &sampleBuffer);
            if (status == kCMBlockBufferNoErr && sampleBuffer) {
                VTDecodeFrameFlags flags = 0;
                VTDecodeInfoFlags flagOut = 0;
                OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(_deocderSession,
                                                                          sampleBuffer,
                                                                          flags,
                                                                          &outputPixelBuffer,
                                                                          &flagOut);
                if(decodeStatus != noErr) {
                    NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                                         code:decodeStatus
                                                     userInfo:nil];
                    NSLog(@"-------------视频解码器解码器失败：%@！------------- ", [error description]);
                }
                CFRelease(sampleBuffer);
            }
            CFRelease(blockBuffer);
        }
    }
    return outputPixelBuffer;
}
/**
 *  释放解码器
 */
-(void)clearDecoder {
    if(_deocderSession) {
        VTDecompressionSessionInvalidate(_deocderSession);
        CFRelease(_deocderSession);
        _deocderSession = NULL;
    }
    if(_decoderFormatDescription) {
        CFRelease(_decoderFormatDescription);
        _decoderFormatDescription = NULL;
    }
}
@end
