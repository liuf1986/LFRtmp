//
//  LFRtmpCommand.h
//  myrtmp
//
//  Created by liuf on 16/7/28.
//
//
/**
 *  rtmp中命令消息的body包装类，body是AMF0协议
 */
#define kLFRtmpConnectSuccess @"NetConnection.Connect.Success"
#define kLFRtmpPublishStart @"NetStream.Publish.Start"
#define kLFRtmpPublishBadName @"NetStream.Publish.BadName"
#define kLFRtmpPlayStart @"NetStream.Play.Start"
#define kLFRtmpPlayReset @"NetStream.Play.Reset"
#define kLFRtmpPlayStreamNotFound @"NetStream.Play.StreamNotFound"
#import <Foundation/Foundation.h>
typedef enum : char {
    LFRtmpResponseCommand_Result=0x1,//_Result命令
    LFRtmpResponseCommandOnBWDone=0x2,//OnBWDone命令
    LFRtmpResponseCommandOnFCPublish=0x3,//OnFCPublish命令
    LFRtmpResponseCommandOnStatus=0x4,//OnStatus命令
    LFRtmpResponseCommandOnFCUnpublish=0x5,//OnFCUnpublish命令
    LFRtmpResponseCommandOnMetaData=0x6,//OnMetaData命令
    LFRtmpResponseCommandUnkonwn=0x7f //未知类型
    
} LFRtmpResponseCommandType;

@interface LFRtmpResponseCommand : NSObject
@property (strong,nonatomic,readonly) NSString *commandName;//命令名称
@property (assign,nonatomic,readonly) int transactionID;//事务id
@property (strong,nonatomic,readonly) NSObject *commandObject;//命令对象参数
@property (strong,nonatomic,readonly) NSObject *optionObject;//可选参数
@property (strong,nonatomic,readonly) NSMutableArray  *allData;
@property (assign,nonatomic,readonly) LFRtmpResponseCommandType commandType;
/**
 *  初始化
 *
 *  @param data 待解码的AMF0数据
 *
 *  @return self
 */
-(instancetype)init:(NSData *)data;
/**
 *  CommandObject是否是ASObject
 *
 *  @return BOOL
 */
-(BOOL)isAsObjectCommandObject;
/**
 *  获取commandObject的数据字典
 *
 *  @return NSDictionary
 */
-(id)getCommandObjectDictionary;
/**
 *  获取commandObject的Array
 *
 *  @return Array
 */
-(id)getCommandObjectArray;
/**
 *  获取commandObject的数据字典的值
 *
 *  @param key 键
 *
 *  @return value
 */
-(id)commandObjectValueForKey:(NSString *)key;
/**
 *  获取commandObjectArray指定下标的数据
 *
 *  @param index 下标
 *
 *  @return value
 */
-(id)commandObjectArrayAt:(NSInteger)index;
/**
 *  optiondObject是否是ASObject
 *
 *  @return BOOL
 */
-(BOOL)isAsObjectOptiondObject;
/**
 *  获取OptionObject的数据字典
 *
 *  @return NSDictionary
 */
-(id)getOptionObjectDictionary;
/**
 *  获取OptionObject的Array
 *
 *  @return Array
 */
-(id)getOptionObjectArray;
/**
 *  获取OptionObject的数据字典的值
 *
 *  @param key 键
 *
 *  @return value
 */
-(id)optionObjectValueForKey:(NSString *)key;
/**
 *  获取OptionObject指定下标的数据
 *
 *  @param index 下标
 *
 *  @return value
 */
-(id)optionObjectArrayAt:(NSInteger)index;

@end
