//
//  LFRtmpCommand.m
//  myrtmp
//
//  Created by liuf on 16/7/28.
//
//

#import "LFRtmpResponseCommand.h"
#import "AMFUnarchiver.h"
#import "ASObject.h"
@implementation LFRtmpResponseCommand
{
    NSData *_data;
}
/**
 *  初始化
 *
 *  @param data 待解码的AMF0数据
 *
 *  @return self
 */
-(instancetype)init:(NSData *)data{
    self=[super init];
    if(self){
        _data=data;
        [self decodeCommand];
    }
    return self;
}
/**
 *  解码AMF0数据
 */
-(void)decodeCommand{
    AMFUnarchiver *unarchiver=[[AMFUnarchiver alloc] initForReadingWithData:_data encoding:kAMF0Encoding];
    @try {
        //获取CommandName的数据
        _commandName=(NSString *)[unarchiver decodeObject];
        _commandType=[self getCmdType:_commandName];
        if(!unarchiver.isAtEnd){
            id object=[unarchiver decodeObject];
            if([object isKindOfClass:[NSNumber class]]){
                _transactionID=[(NSNumber *)object intValue];
            }
        }
        if(!unarchiver.isAtEnd){
            _commandObject=[unarchiver decodeObject];
        }
        if(!unarchiver.isAtEnd){
            _optionObject=[unarchiver decodeObject];
        }
        unarchiver=[[AMFUnarchiver alloc] initForReadingWithData:_data encoding:kAMF0Encoding];
        [unarchiver decodeObject];
        _allData=[NSMutableArray new];
        while (YES) {
            if(unarchiver.isAtEnd){
                break;
            }else{
                @try {
                    id object=[unarchiver decodeObject];
                    if([object isKindOfClass:[ASObject class]]){
                        ASObject *asObject=(ASObject *)object;
                        [_allData addObject:asObject.properties];
                    }else{
                        [_allData addObject:object];
                    }
                } @catch (NSException *exception) {
                    break;
                }
            }
        }
        
    } @catch (NSException *exception) {
        NSLog(@"--------------RTMP：调用decodeCommand异常！--------------");
    }
}
-(BOOL)isAsObjectCommandObject{
    if(_commandObject&&[_commandObject isKindOfClass:[ASObject class]]){
        return YES;
    }
    return NO;
}
/**
 *  获取commandObject的数据字典
 *
 *  @return NSDictionary
 */
-(id)getCommandObjectDictionary{
    if([self isAsObjectCommandObject]){
        ASObject *object=(ASObject *)_commandObject;
        return object.properties;
    }
    return nil;
}
/**
 *  获取commandObject的Array
 *
 *  @return Array
 */
-(id)getCommandObjectArray{
    if([self isAsObjectCommandObject]){
        ASObject *object=(ASObject *)_commandObject;
        return object.data;
    }
    return nil;
}
/**
 *  获取commandObject的数据字典的值
 *
 *  @param key 键
 *
 *  @return value
 */
-(id)commandObjectValueForKey:(NSString *)key{
    NSDictionary *dic=[self getCommandObjectDictionary];
    if(dic&&[dic isKindOfClass:[NSDictionary class]]&&key.length){
        return [dic valueForKey:key];
    }
    return nil;
}
/**
 *  获取commandObjectArray指定下标的数据
 *
 *  @param index 下标
 *
 *  @return value
 */
-(id)commandObjectArrayAt:(NSInteger)index{
    NSArray *array=[self getCommandObjectArray];
    if(array&&[array isKindOfClass:[NSArray class]]&&index<=array.count-1){
        return  [array objectAtIndex:index];
    }
    return nil;
}
/**
 *  optiondObject是否是ASObject
 *
 *  @return BOOL
 */
-(BOOL)isAsObjectOptiondObject{
    if(_optionObject&&[_optionObject isKindOfClass:[ASObject class]]){
        return YES;
    }
    return NO;
}
/**
 *  获取OptionObject的数据字典
 *
 *  @return NSDictionary
 */
-(id)getOptionObjectDictionary{
    if([self isAsObjectOptiondObject]){
        ASObject *object=(ASObject *)_optionObject;
        return object.properties;
    }
    return nil;
}
/**
 *  获取OptionObject的Array
 *
 *  @return Array
 */
-(id)getOptionObjectArray{
    if([self isAsObjectOptiondObject]){
        ASObject *object=(ASObject *)_optionObject;
        return object.data;
    }
    return nil;
}
/**
 *  获取OptionObject的数据字典的值
 *
 *  @param key 键
 *
 *  @return value
 */
-(id)optionObjectValueForKey:(NSString *)key{
    NSDictionary *dic=[self getOptionObjectDictionary];
    if(dic&&[dic isKindOfClass:[NSDictionary class]]&&key.length){
        return [dic valueForKey:key];
    }
    return nil;
}
/**
 *  获取OptionObject指定下标的数据
 *
 *  @param index 下标
 *
 *  @return value
 */
-(id)optionObjectArrayAt:(NSInteger)index{
    NSArray *array=[self getOptionObjectArray];
    if(array&&[array isKindOfClass:[NSArray class]]&&index<=array.count-1){
        return  [array objectAtIndex:index];
    }
    return nil;
}
/**
 *  获取command的类型
 *
 *  @param cmdName 命令名称
 *
 *  @return LFRtmpCommandType
 */
-(LFRtmpResponseCommandType)getCmdType:(NSString *)cmdName{
    LFRtmpResponseCommandType cmdType=LFRtmpResponseCommandUnkonwn;
    cmdName=[cmdName uppercaseString];
    if([cmdName isEqualToString:@"_RESULT"]){
        cmdType=LFRtmpResponseCommand_Result;
    }else if([cmdName isEqualToString:@"ONBWDONE"]){
        cmdType=LFRtmpResponseCommandOnBWDone;
    }else if([cmdName isEqualToString:@"ONFCPUBLISH"]){
        cmdType=LFRtmpResponseCommandOnFCPublish;
    }else if([cmdName isEqualToString:@"ONSTATUS"]){
        cmdType=LFRtmpResponseCommandOnStatus;
    }else if([cmdName isEqualToString:@"ONFCUNPUBLISH"]){
        cmdType=LFRtmpResponseCommandOnFCUnpublish;
    }else if([cmdName isEqualToString:@"ONMETADATA"]){
        cmdType=LFRtmpResponseCommandOnMetaData;
    }
    return cmdType;
}
@end
