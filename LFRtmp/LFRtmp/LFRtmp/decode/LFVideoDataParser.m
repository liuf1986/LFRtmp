//
//  LFVideoDataParser.m
//  LFRtmp
//
//  Created by liuf on 2017/5/17.
//  Copyright © 2017年 liufang. All rights reserved.
//

#import "LFVideoDataParser.h"
@implementation LFVideoDataParser
/**
 *  解析视频同步头数据，并将结果给到LFPlayConfig
 *
 *  @param data 同步头数据
 *  @param config 存放解析结果
 *  @return 是否解析成功
 */
+(BOOL)parseVideoSequenceHeader:(NSData *)data withConfig:(LFPlayConfig *)config{

    
    const char *bytes=data.bytes;
    if(bytes[1]!=0x0){
        NSLog(@"--------------VideoDataParser:这不是视频同步包--------------");
    }else{
        //视频同步包的数据构成参见FLV官方文档Video Tags章节
        //获取frameType和CodecID，分别位于首字节的前四位和后四位
        uint8_t frameType=((uint8_t)bytes[0])>>4;
        if(frameType!=LFPlayVideoFrameKeyFrame){
            NSLog(@"--------------VideoDataParser:不支持(%@)的视频帧类型--------------",[LFPlayConfig getVideoFrameTypeDes:frameType]);
        }else{
            config.frameType=frameType;
            uint8_t codecID=((uint8_t)bytes[0])&0x0F;
            if(codecID!=LFPlayVideoCodecIDAVC){
                 NSLog(@"--------------VideoDataParser:不支持(%@)视频编解码器--------------",[LFPlayConfig getVideoCodecIDDes:codecID]);
            }else{
                NSLog(@"--------------VideoDataParser:视频采用h264编码器IDR--------------");
                //获取sps数据
                //获取sps 1-3位的数据，用于数据校验,详细描述参见FLV Video Tags章节AVCDecoderConfigurationRecord
                uint8_t spsCheck[3]={0};
                spsCheck[0]=bytes[6];
                spsCheck[1]=bytes[7];
                spsCheck[2]=bytes[8];
                //获取sps数据长度,在同步包数据的11，12字节
                uint16_t spsLength=((uint16_t)(((uint16_t)bytes[11])<<8))|((uint16_t)bytes[12]);
                NSMutableData *spsData=[NSMutableData new];
                [spsData setLength:spsLength];
                uint8_t *spsBytes=spsData.mutableBytes;
                for(int i=0;i<spsLength;i++){
                    spsBytes[i]=bytes[13+i];
                }
                if(memcmp(spsCheck,spsBytes+1,3)!=0){
                    NSLog(@"--------------VideoDataParser:sps数据校验失败--------------");
                }else{
                    config.sps=spsData;
                    //获取pps数据长度,在同步包数据的sps后间隔一位，同样占两个字节
                    int ppsIndex=13+spsLength+1;
                    uint16_t ppsLength=((uint16_t)(((uint16_t)bytes[ppsIndex])<<8))|((uint16_t)bytes[ppsIndex+1]);
                    NSMutableData *ppsData=[NSMutableData new];
                    [ppsData setLength:ppsLength];
                    uint8_t *ppsBytes=ppsData.mutableBytes;
                    for(int i=0;i<ppsLength;i++){
                        ppsBytes[i]=bytes[ppsIndex+2+i];
                    }
                    config.pps=ppsData;
                }
            }
        }
        
    }
    return NO;
}
/**
 *  解析视频数据包
 *
 *  @param data 视频数据包
 *  @return 清除了FLV tag 后的数据
 */
+(LFVideoPacketData *)parseVideoData:(NSData *)data{
    LFVideoPacketData *videoPacket=nil;
    if(data.length>9){
        const char *bytes=data.bytes;
        if(bytes[1]!=0x1){
            NSLog(@"--------------VideoDataParser:这不是视频数据包--------------");
        }else{
            //获取首字节的frame type和codecID
            //获取frameType和CodecID，分别位于首字节的前四位和后四位
            uint8_t frameType=((uint8_t)bytes[0])>>4;
            if(frameType!=LFPlayVideoFrameKeyFrame&&frameType!=LFPlayVideoFrameInterFrame){
                NSLog(@"--------------VideoDataParser解析视频数据包:不支持(%@)的视频帧类型--------------",[LFPlayConfig getVideoFrameTypeDes:frameType]);
            }else{
                uint8_t codecID=((uint8_t)bytes[0])&0x0F;
                if(codecID!=LFPlayVideoCodecIDAVC){
                    NSLog(@"--------------VideoDataParser解析视频数据包:不支持(%@)视频编解码器--------------",[LFPlayConfig getVideoCodecIDDes:codecID]);
                }else{
                    videoPacket=[LFVideoPacketData new];
                    videoPacket.codecID=codecID;
                    videoPacket.isKeyFrame=frameType==LFPlayVideoFrameKeyFrame?YES:NO;
                    videoPacket.datas=[NSMutableArray new];
                    int index=5;
                    while (YES) {
                        //获取四位的NALU length
                        if(data.length>index+4){
                            uint32_t b1=(((uint32_t)bytes[index])<<24);
                            uint32_t b2=(((uint32_t)bytes[index+1])<<16);
                            uint32_t b3=(((uint32_t)bytes[index+2])<<8);
                            uint8_t b4=(uint8_t)bytes[index+3];
                            uint32_t length=b1|b2|b3|b4;
                            //用于解码的数据包含了四位的数据长度信息，并不需要添加分割标示00 00 00 01
                            //流数据已经是独立的数据包构成，分割标示00 00 00 01适用于文件存储和解析
                            NSMutableData *h264Data=[NSMutableData dataWithData:[data subdataWithRange:NSMakeRange(index, length+4)]];
                            [videoPacket.datas addObject:h264Data];
                            index=index+4+length;
                        }else{
                            break;
                        }
                    }
                }
            }
        }
    }
    return videoPacket;
}
@end
