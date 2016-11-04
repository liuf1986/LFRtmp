//
//  LFRtmpBasicHeader.m
//  myrtmp
//
//  Created by liuf on 16/7/22.
// 
//

#import "LFRtmpBasicHeader.h"

@implementation LFRtmpBasicHeader
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
          byteCount:(LFRtmpBasicHeaderByteCount)byteCount{
    self=[super init];
    if(self){
        _fmtType=fmtType;
        _chunkStreamID=chunkStreamID;
        _byteCount=byteCount;
    }
    return self;
}

/**
 *  通过一字节的数据解析出实例对象
 *
 *  @param headerData 一字节数据
 *
 *  @return self
 */
+(instancetype)basicHeader:(uint8_t)headerData{
    LFRtmpBasicHeaderFmtType fmt=[LFRtmpBasicHeader getFmtType:headerData>>6];
    uint8_t streamIdData=headerData<<2;
    streamIdData=streamIdData>>2;
    return [[LFRtmpBasicHeader alloc] init:fmt
                             chunkStreamID:streamIdData
                                 byteCount:(LFRtmpBasicHeaderByteCount1)];
}

/**
 *  返回basic header数据
 *
 *  @return 返回basic header数据
 */
-(NSData *)data{
    NSMutableData *data=[NSMutableData data];
    uint8_t *bytes=[data mutableBytes];
    switch (_byteCount) {
        case LFRtmpBasicHeaderByteCount1:
        {
            //左移6位只保留低两位
            uint8_t fmtByte=_fmtType<<6;
            //右移两位舍弃高两位
            [data setLength:LFRtmpBasicHeaderByteCount1];
            bytes[0]=fmtByte|_chunkStreamID;
            
        }
            break;
        case LFRtmpBasicHeaderByteCount2:
        {
            //左移6位只保留低两位
            uint8_t fmtByte=_fmtType<<6;
            uint16_t streamIDByte=(_chunkStreamID<<2)>>2;
            [data setLength:LFRtmpBasicHeaderByteCount2];
            bytes[0]=fmtByte|(streamIDByte>>8);
            bytes[1]=streamIDByte;
        }
            break;
        case LFRtmpBasicHeaderByteCount3:
        {
            //左移6位只保留低两位
            uint8_t fmtByte=_fmtType<<6;
            //右移两位舍弃高两位
            uint32_t streamIDByte=(_chunkStreamID<<10)>>10;
            streamIDByte=streamIDByte>>2;
            [data setLength:LFRtmpBasicHeaderByteCount3];
            bytes[0]=fmtByte|(streamIDByte>>16);
            bytes[1]=streamIDByte>>8;
            bytes[2]=streamIDByte;
        }
            break;
        default:
            break;
    }
    return data;
}

#pragma mark private method

+(LFRtmpBasicHeaderFmtType)getFmtType:(uint8_t)fmtData{
    LFRtmpBasicHeaderFmtType fmt=LFRtmpBasicHeaderFmtUnkonwn;
    switch (fmtData) {
        case LFRtmpBasicHeaderFmtLarge:
        {
            fmt=LFRtmpBasicHeaderFmtLarge;
        }
            break;
        case LFRtmpBasicHeaderFmtMedium:
        {
            fmt=LFRtmpBasicHeaderFmtMedium;
        }
            break;
        case LFRtmpBasicHeaderFmtSmall:
        {
            fmt=LFRtmpBasicHeaderFmtSmall;
        }
            break;
        case LFRtmpBasicHeaderFmtMin:
        {
            fmt=LFRtmpBasicHeaderFmtMin;
        }
            break;
        default:
            break;
    }
    return fmt;
}
@end
