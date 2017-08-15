//
//  LFAudioDataParser.m
//  LFRtmp
//
//  Created by liuf on 2017/5/17.
//  Copyright © 2017年 liufang. All rights reserved.
//

#import "LFAudioDataParser.h"

@implementation LFAudioDataParser
/**
 *  解析音频同步头数据，并将结果给到LFPlayConfig
 *
 *  @param data 同步头数据
 *  @param config 存放解析结果
 *  @return 是否解析成功
 */
+(BOOL)parseAudioSequenceHeader:(NSData *)data withConfig:(LFPlayConfig *)config{
    if(data.length!=4){
        NSLog(@"--------------AudioDataParser:这不是音频同步头数据！--------------");
    }else{
        const char * bytes=[data bytes];
        //0为同步包，1为音频数据包
        if(bytes[1]!=0x0){
            NSLog(@"--------------AudioDataParser:这不是音频同步头数据！类型是:%d--------------",bytes[1]);
        }else{
            uint8_t byte=bytes[0];
            //获取首字节前四位
            uint8_t ub4=byte>>4;
            config.audiocodecid=ub4;
            NSLog(@"--------------AudioDataParser:音频编码类型为：%@！--------------",[LFPlayConfig getAudioFormatDes:ub4]);
            //首字节中间2位为flv tag音频的封包采样率
            uint8_t ub2=((uint8_t)(byte<<4))>>6;
            switch (ub2) {
                case 0:
                {
                    //5.5khz
                    config.flvTagAudiosamplerate=5500;
                }
                    break;
                case 1:
                {
                    //11khz
                    config.flvTagAudiosamplerate=11000;
                }
                    break;
                case 2:
                {
                    //22khz
                    config.flvTagAudiosamplerate=22000;
                }
                    break;
                case 3:
                {
                    //44khz
                    config.flvTagAudiosamplerate=44100;
                }
                    break;
                default:
                    break;
            }
            //首字节中间6位为位元深度
            uint8_t ub1=((uint8_t)(byte<<6))>>7;
            if(ub1==0){
                config.audiosamplesize=8;
            }else if(ub1==1){
                config.audiosamplesize=16;
            }
            //首字节最后一位声道类型
            ub1=((uint8_t)(byte<<7))>>7;
            config.stereo=ub1;
            //第三和第四字节为AudioSpecificConfig，由AAC Profile 5bits | 采样率 4bits | 声道数 4bits | 其他 3bits | 构成
            config.aacProfile=(uint8_t)((uint8_t)bytes[2]>>3);
            uint16_t byte3=((uint16_t)bytes[2])<<8;
            uint8_t byte4=(uint8_t)bytes[3];
            uint16_t accProfile=byte3|byte4;
            config.audioSamplerateid=((uint16_t)(accProfile<<5))>>12;
            return YES;
        }
    }
    return NO;
}
/**
 *  解析音频数据
 *
 *  @param data 音频数据
 *  @return 清除了FLV tag 后的数据
 */
+(NSData *)parseAudioData:(NSData *)data{
    if(data.length>2){
        return [data subdataWithRange:NSMakeRange(2, data.length-2)];
    }
    return nil;
}
@end
