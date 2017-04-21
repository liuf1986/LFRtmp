//
//  AMFMutableByteArray.m
//  CocoaAMF
//
//  Created by Marc Bauer on 13.01.09.
//  Copyright 2009 nesiumdotcom. All rights reserved.
//

#import "AMFArchiver.h"

@class AMF3TraitsInfo;

@interface AMFArchiver ()
- (id)initForWritingWithMutableData:(NSMutableData *)data;

- (void)_ensureLength:(unsigned)length;
- (void)_ensureIntegrityOfSerializedObject;
- (void)_appendBytes:(const void *)bytes length:(NSUInteger)length;
- (void)_setCollectionWriteContext:(NSObject *)obj;
- (void)_restoreCollectionWriteContext;

- (void)_encodeDate:(NSDate *)value;
- (void)_encodeArray:(NSArray *)value;
- (void)_encodeDictionary:(NSDictionary *)value;
- (void)_encodeNumber:(NSNumber *)value omitType:(BOOL)omitType;
- (void)_encodeASObject:(ASObject *)value;
- (void)_encodeCustomObject:(id)value;
- (void)_encodeString:(NSString *)value omitType:(BOOL)omitType;
- (void)_encodeNull;
@end

@interface AMF0Archiver ()
@end

@interface AMF3Archiver ()
- (void)_encodeTraits:(AMF3TraitsInfo *)traits;
- (void)_encodeData:(NSData *)value;
- (void)_encodeMixedArray:(NSDictionary *)value;
@end

@interface _AMFStringData : NSObject{
    NSData *data;
}
@property (nonatomic, retain) NSData *data;
+ (_AMFStringData *)stringDataWithData:(NSData *)theData;
@end

@interface _AMFPlainData : NSObject{
    NSData *data;
}
@property (nonatomic, retain) NSData *data;
+ (_AMFPlainData *)plainDataWithData:(NSData *)theData;
@end

@interface _AMFNumber : NSObject{
    NSNumber *value;
}
@property (nonatomic, retain) NSNumber *value;
+ (_AMFNumber *)numberWithNSNumber:(NSNumber *)number;
@end


@implementation AMFArchiver

static NSMutableDictionary *g_registeredClasses = nil;
static uint16_t g_options = 0;

#pragma mark -
#pragma mark Initialization & Deallocation

+ (void)initialize{
    [[self class] setClassName:[FlexArrayCollection AMFClassAlias]
                      forClass:[FlexArrayCollection class]];
    [[self class] setClassName:[FlexObjectProxy AMFClassAlias]
                      forClass:[FlexObjectProxy class]];
    [[self class] setClassName:[FlexCommandMessage AMFClassAlias]
                      forClass:[FlexCommandMessage class]];
    [[self class] setClassName:[FlexAcknowledgeMessage AMFClassAlias]
                      forClass:[FlexAcknowledgeMessage class]];
    [[self class] setClassName:[FlexRemotingMessage AMFClassAlias]
                      forClass:[FlexRemotingMessage class]];
    [[self class] setClassName:[FlexErrorMessage AMFClassAlias]
                      forClass:[FlexErrorMessage class]];
}

- (id)init{
    if (self = [super init]){
        m_data = [[NSMutableData alloc] init];
        m_position = 0;
        m_bytes = [m_data mutableBytes];
        m_objectTable = [[NSMutableArray alloc] init];
        m_currentObjectToSerialize = nil;
        m_currentObjectToWrite = nil;
        m_registeredClasses = [[NSMutableDictionary alloc] init];
        m_serializationStack = nil;
        m_writeStack = nil;
    }
    return self;
}

- (id)initForWritingWithMutableData:(NSMutableData *)data encoding:(AMFEncoding)encoding{
    NSZone *temp = [self zone];  // Must not call methods after release
    [self release];              // Placeholder no longer needed
    return (encoding == kAMF0Encoding)
    ? [[AMF0Archiver allocWithZone:temp] initForWritingWithMutableData:data]
    : [[AMF3Archiver allocWithZone:temp] initForWritingWithMutableData:data];
}

- (id)initForWritingWithMutableData:(NSMutableData *)data{
    if (self = [self init]){
        [data retain];
        [m_data release];
        m_data = data;
        m_bytes = [m_data mutableBytes];
    }
    return self;
}

+ (NSData *)archivedDataWithRootObject:(id)rootObject encoding:(AMFEncoding)encoding{
    AMFArchiver *archiver = [[[AMFArchiver alloc] initForWritingWithMutableData:[NSMutableData data]
                                                                       encoding:encoding] autorelease];
    [archiver encodeRootObject:rootObject];
    return [archiver data];
}

+ (BOOL)archiveRootObject:(id)rootObject encoding:(AMFEncoding)encoding toFile:(NSString *)path{
    NSData *data = [self archivedDataWithRootObject:rootObject encoding:encoding];
    return [data writeToFile:path atomically:YES];
}

- (void)dealloc{
    [m_objectTable release];
    [m_data release];
    [m_registeredClasses release];
    [m_serializationStack release];
    [m_writeStack release];
    [super dealloc];
}



#pragma mark -
#pragma mark Public methods

- (BOOL)allowsKeyedCoding{
    if (m_currentObjectToSerialize == nil || m_currentObjectToSerialize.data != nil)
        return NO;
    return YES;
}

- (NSData *)data{
    return [[m_data copy] autorelease];
}

- (NSMutableData *)archiverData{
    return m_data;
}

- (void)encodeRootObject:(id)rootObject{
    [self encodeObject:rootObject];
}

- (void)setClassName:(NSString *)codedName forClass:(Class)cls{
    if (codedName == nil)
        [m_registeredClasses removeObjectForKey:cls];
    else
        [m_registeredClasses setObject:codedName forKey:cls];
}

+ (void)setClassName:(NSString *)codedName forClass:(Class)cls{
    if (!g_registeredClasses) g_registeredClasses = [[NSMutableDictionary alloc] init];
    if (codedName == nil)
        [g_registeredClasses removeObjectForKey:cls];
    else
        [g_registeredClasses setObject:codedName forKey:cls];
}

- (NSString *)classNameForClass:(Class)cls{
    return [m_registeredClasses objectForKey:cls];
}

+ (NSString *)classNameForClass:(Class)cls{
    return [g_registeredClasses objectForKey:cls];
}

+ (void)setOptions:(uint16_t)options{
    g_options = options;
}

+ (uint16_t)options{
    return g_options;
}

- (void)encodeBool:(BOOL)value forKey:(NSString *)key{
    [m_currentObjectToSerialize setValue:[NSNumber numberWithBool:value] forKey:key];
    [self _ensureIntegrityOfSerializedObject];
}

- (void)encodeDouble:(double)value forKey:(NSString *)key{
    [m_currentObjectToSerialize setValue:[NSNumber numberWithDouble:value] forKey:key];
    [self _ensureIntegrityOfSerializedObject];
}

- (void)encodeFloat:(float)value forKey:(NSString *)key{
    [m_currentObjectToSerialize setValue:[NSNumber numberWithFloat:value] forKey:key];
    [self _ensureIntegrityOfSerializedObject];
}

- (void)encodeInt32:(int32_t)value forKey:(NSString *)key{
    [m_currentObjectToSerialize setValue:[NSNumber numberWithInt:value] forKey:key];
    [self _ensureIntegrityOfSerializedObject];
}

- (void)encodeInt64:(int64_t)value forKey:(NSString *)key{
    [m_currentObjectToSerialize setValue:[NSNumber numberWithInteger:value] forKey:key];
    [self _ensureIntegrityOfSerializedObject];
}

- (void)encodeInt:(int)value forKey:(NSString *)key{
    [m_currentObjectToSerialize setValue:[NSNumber numberWithInt:value] forKey:key];
    [self _ensureIntegrityOfSerializedObject];
}

- (void)encodeObject:(id)value forKey:(NSString *)key{
    [m_currentObjectToSerialize setValue:value forKey:key];
    [self _ensureIntegrityOfSerializedObject];
}

- (void)encodeValueOfObjCType:(const char *)valueType at:(const void *)address{
}

- (void)encodeBool:(BOOL)value{
    if (m_currentObjectToSerialize != nil){
        [m_currentObjectToSerialize addObject:[NSNumber numberWithBool:value]];
        [self _ensureIntegrityOfSerializedObject];
        return;
    }
    [self encodeUnsignedChar:(value ? 1 : 0)];
}

- (void)encodeChar:(int8_t)value{
    if (m_currentObjectToSerialize != nil){
        [m_currentObjectToSerialize addObject:[_AMFNumber numberWithNSNumber:
                                               [NSNumber numberWithChar:value]]];
        [self _ensureIntegrityOfSerializedObject];
        return;
    }
    [self _ensureLength:1];
    m_bytes[m_position++] = value;
}

- (void)encodeDataObject:(NSData *)value{
    if (m_currentObjectToSerialize != nil){
        [m_currentObjectToSerialize addObject:[_AMFPlainData plainDataWithData:value]];
        [self _ensureIntegrityOfSerializedObject];
        return;
    }
    [m_data appendData:value];
    m_bytes = [m_data mutableBytes];
    m_position = [m_data length];
}

- (void)encodeDouble:(double)value{
    if (m_currentObjectToSerialize != nil){
        [m_currentObjectToSerialize addObject:[_AMFNumber numberWithNSNumber:
                                               [NSNumber numberWithDouble:value]]];
        [self _ensureIntegrityOfSerializedObject];
        return;
    }
    uint8_t *ptr = (void *)&value;
    [self _ensureLength:8];
    m_bytes[m_position++] = ptr[7];
    m_bytes[m_position++] = ptr[6];
    m_bytes[m_position++] = ptr[5];
    m_bytes[m_position++] = ptr[4];
    m_bytes[m_position++] = ptr[3];
    m_bytes[m_position++] = ptr[2];
    m_bytes[m_position++] = ptr[1];
    m_bytes[m_position++] = ptr[0];
}

- (void)encodeFloat:(float)value{
    if (m_currentObjectToSerialize != nil){
        [m_currentObjectToSerialize addObject:[_AMFNumber numberWithNSNumber:
                                               [NSNumber numberWithFloat:value]]];
        [self _ensureIntegrityOfSerializedObject];
        return;
    }
    uint8_t *ptr = (void *)&value;
    [self _ensureLength:4];
    m_bytes[m_position++] = ptr[3];
    m_bytes[m_position++] = ptr[2];
    m_bytes[m_position++] = ptr[1];
    m_bytes[m_position++] = ptr[0];
}

- (void)encodeInt:(int32_t)value{
    if (m_currentObjectToSerialize != nil){
        [m_currentObjectToSerialize addObject:[_AMFNumber numberWithNSNumber:
                                               [NSNumber numberWithInt:value]]];
        [self _ensureIntegrityOfSerializedObject];
        return;
    }
    value = CFSwapInt32HostToBig(value);
    [self _appendBytes:&value length:sizeof(int32_t)];
}

- (void)encodeMultiByteString:(NSString *)value encoding:(NSStringEncoding)encoding{
    if (m_currentObjectToSerialize != nil){
        [m_currentObjectToSerialize addObject:[_AMFStringData stringDataWithData:
                                               [value dataUsingEncoding:encoding]]];
        [self _ensureIntegrityOfSerializedObject];
        return;
    }
    [self encodeDataObject:[value dataUsingEncoding:encoding]];
}

- (void)encodeObject:(NSObject *)value{
    if ([value isKindOfClass:[NSString class]]){
        if (m_currentObjectToSerialize != nil){
            [m_currentObjectToSerialize addObject:value];
            [self _ensureIntegrityOfSerializedObject];
            return;
        }
        [self _encodeString:(NSString *)value omitType:NO];
    }else if ([value isKindOfClass:[NSNumber class]]){
        if (m_currentObjectToSerialize != nil){
            [m_currentObjectToSerialize addObject:value];
            [self _ensureIntegrityOfSerializedObject];
            return;
        }
        [self _encodeNumber:(NSNumber *)value omitType:NO];
    }else if ([value isKindOfClass:[NSDate class]]){
        if (m_currentObjectToSerialize != nil){
            [m_currentObjectToSerialize addObject:value];
            [self _ensureIntegrityOfSerializedObject];
            return;
        }
        [self _encodeDate:(NSDate *)value];
    }else if ([value isKindOfClass:[NSNull class]] || value == nil){
        if (m_currentObjectToSerialize != nil){
            [m_currentObjectToSerialize addObject:[NSNull null]];
            [self _ensureIntegrityOfSerializedObject];
            return;
        }
        [self _encodeNull];
    }else if ([value isKindOfClass:[NSArray class]]){
        if ((g_options & AMFArchiverPackArrayOption) && [self isMemberOfClass:[AMF3Archiver class]] &&
            !([m_currentObjectToSerialize.type isEqual:[FlexArrayCollection AMFClassAlias]] ||
              ([m_currentObjectToWrite isMemberOfClass:[ASObject class]] &&
               [[(ASObject *)m_currentObjectToWrite type] isEqual:[FlexArrayCollection AMFClassAlias]]))){
                  // the cast looks funny, but convices gcc that we really have a FlexArrayCollection here
                  value = [[(FlexArrayCollection *)[FlexArrayCollection alloc]
                            initWithSource:(NSArray *)value] autorelease];
                  // if we're on write it out, otherwise just let it slip through
                  if (m_currentObjectToSerialize == nil){
                      [self _encodeCustomObject:value];
                      return;
                  }
              }
        
        if (m_currentObjectToSerialize != nil){
            [m_currentObjectToSerialize addObject:value];
            [self _ensureIntegrityOfSerializedObject];
            return;
        }
        [self _setCollectionWriteContext:value];
        [self _encodeArray:(NSArray *)value];
        [self _restoreCollectionWriteContext];
    }else if ([value isKindOfClass:[NSDictionary class]]){
        if (m_currentObjectToSerialize != nil){
            [m_currentObjectToSerialize addObject:value];
            [self _ensureIntegrityOfSerializedObject];
            return;
        }
        [self _setCollectionWriteContext:value];
        [self _encodeDictionary:(NSDictionary *)value];
        [self _restoreCollectionWriteContext];
    }else if ([value isKindOfClass:[ASObject class]]){
        if (m_currentObjectToSerialize != nil){
            [m_currentObjectToSerialize addObject:value];
            [self _ensureIntegrityOfSerializedObject];
            return;
        }
        [self _setCollectionWriteContext:value];
        [self _encodeASObject:(ASObject *)value];
        [self _restoreCollectionWriteContext];
    }else if ([value isKindOfClass:[_AMFStringData class]]){
        if (m_currentObjectToSerialize != nil){
            [m_currentObjectToSerialize addObject:value];
            [self _ensureIntegrityOfSerializedObject];
            return;
        }
        [self encodeDataObject:[(_AMFStringData *)value data]];
    }else if ([value isKindOfClass:[_AMFPlainData class]]){
        if (m_currentObjectToSerialize != nil){
            [m_currentObjectToSerialize addObject:value];
            [self _ensureIntegrityOfSerializedObject];
            return;
        }
        [self encodeUnsignedChar:kAMF3ByteArrayType];
        NSData *d = [(_AMFPlainData *)value data];
        [self encodeUnsignedInt29:(([d length] << 1) | 1)];
        [self encodeDataObject:d];
    }else if ([value isKindOfClass:[_AMFNumber class]]){
        if (m_currentObjectToSerialize != nil){
            [m_currentObjectToSerialize addObject:value];
            [self _ensureIntegrityOfSerializedObject];
            return;
        }
        [self _encodeNumber:[(_AMFNumber *)value value] omitType:YES];
    }else if ([value isKindOfClass:[NSData class]] && m_currentObjectToSerialize == nil){
        [self encodeUnsignedChar:kAMF3ByteArrayType];
        NSData *d = (NSData *)value;
        [self encodeUnsignedInt29:(([d length] << 1) | 1)];
        [self encodeDataObject:d];
    }else{
        if (m_currentObjectToSerialize != nil){
            [m_currentObjectToSerialize addObject:value];
            [self _ensureIntegrityOfSerializedObject];
            return;
        }
        [self _encodeCustomObject:value];
    }
}

- (void)encodeShort:(int16_t)value{
    if (m_currentObjectToSerialize != nil){
        [m_currentObjectToSerialize addObject:[_AMFNumber numberWithNSNumber:
                                               [NSNumber numberWithShort:value]]];
        [self _ensureIntegrityOfSerializedObject];
        return;
    }
    value = CFSwapInt16HostToBig(value);
    [self _appendBytes:&value length:sizeof(int16_t)];
}

- (void)encodeUnsignedInt:(uint32_t)value{
    if (m_currentObjectToSerialize != nil){
        [m_currentObjectToSerialize addObject:[_AMFNumber numberWithNSNumber:
                                               [NSNumber numberWithUnsignedInt:value]]];
        [self _ensureIntegrityOfSerializedObject];
        return;
    }
    value = CFSwapInt32HostToBig(value);
    [self _appendBytes:&value length:sizeof(uint32_t)];
}

- (void)encodeUTF:(NSString *)value{
    if (m_currentObjectToSerialize != nil){
        [m_currentObjectToSerialize addObject:(value == nil ? [NSString string] : value)];
        [self _ensureIntegrityOfSerializedObject];
        return;
    }
    if (value == nil){
        [self encodeUnsignedShort:0];
        return;
    }
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    [self encodeUnsignedShort:[data length]];
    [self encodeDataObject:data];
}

- (void)encodeUTFBytes:(NSString *)value{
    if (value == nil){
        return;
    }
    if (m_currentObjectToSerialize != nil){
        [m_currentObjectToSerialize addObject:[_AMFStringData stringDataWithData:[value
                                                                                  dataUsingEncoding:NSUTF8StringEncoding]]];
        [self _ensureIntegrityOfSerializedObject];
        return;
    }
    [self encodeDataObject:[value dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)encodeUnsignedChar:(uint8_t)value{
    if (m_currentObjectToSerialize != nil){
        [m_currentObjectToSerialize addObject:[_AMFNumber numberWithNSNumber:
                                               [NSNumber numberWithUnsignedChar:value]]];
        [self _ensureIntegrityOfSerializedObject];
        return;
    }
    [self _ensureLength:1];
    m_bytes[m_position++] = value;
}

- (void)encodeUnsignedShort:(uint16_t)value{
    if (m_currentObjectToSerialize != nil){
        [m_currentObjectToSerialize addObject:[_AMFNumber numberWithNSNumber:
                                               [NSNumber numberWithUnsignedShort:value]]];
        [self _ensureIntegrityOfSerializedObject];
        return;
    }
    [self _ensureLength:2];
    m_bytes[m_position++] = (value >> 8) & 0xFF;
    m_bytes[m_position++] = value & 0xFF;
}

- (void)encodeUnsignedInt29:(int32_t)value{
    if (m_currentObjectToSerialize != nil){
        [m_currentObjectToSerialize addObject:[NSNumber numberWithInt:value]];
        [self _ensureIntegrityOfSerializedObject];
        return;
    }
    value &= 0x1fffffff;
    if (value < 0x80){
        [self _ensureLength:1];
        m_bytes[m_position++] = value;
    }else if (value < 0x4000){
        [self _ensureLength:2];
        m_bytes[m_position++] = ((value >> 7) & 0x7F) | 0x80;
        m_bytes[m_position++] = (value & 0x7F);
    }else if (value < 0x200000){
        [self _ensureLength:3];
        m_bytes[m_position++] = ((value >> 14) & 0x7F) | 0x80;
        m_bytes[m_position++] = ((value >> 7) & 0x7F) | 0x80;
        m_bytes[m_position++] = (value & 0x7F);
    }else{
        [self _ensureLength:4];
        m_bytes[m_position++] = ((value >> 22) & 0x7F) | 0x80;
        m_bytes[m_position++] = ((value >> 15) & 0x7F) | 0x80;
        m_bytes[m_position++] = ((value >> 8) & 0x7F) | 0x80;
        m_bytes[m_position++] = (value & 0xFF);
    }
}



#pragma mark -
#pragma mark Private methods

- (void)_ensureLength:(unsigned)length{
    [m_data setLength:[m_data length] + length];
    m_bytes = [m_data mutableBytes];
}

- (void)_ensureIntegrityOfSerializedObject{
    // prevents mixing of keyed-archiving (non-externalizable classes) and non-keyed-archiving
    // (externalizable classes)
    if (m_currentObjectToSerialize.data != nil && m_currentObjectToSerialize.properties != nil){
        [NSException raise:NSInternalInconsistencyException format:@"You may not mix keyed archiving \
         and non-keyed archiving on the same object!"];
    }
}

- (void)_encodeDate:(NSDate *)value{
    // overridden in subclasses
    [self doesNotRecognizeSelector:_cmd];
}

- (void)_encodeArray:(NSArray *)value{
    // overridden in subclasses
    [self doesNotRecognizeSelector:_cmd];
}

- (void)_encodeDictionary:(NSDictionary *)value{
    // overridden in subclasses
    [self doesNotRecognizeSelector:_cmd];
}

- (void)_encodeNumber:(NSNumber *)value omitType:(BOOL)omitType{
    // overridden in subclasses
    [self doesNotRecognizeSelector:_cmd];
}

- (void)_encodeASObject:(ASObject *)value{
    // overridden in subclasses
    [self doesNotRecognizeSelector:_cmd];
}

- (void)_encodeString:(NSString *)value omitType:(BOOL)omitType{
    // overridden in subclasses
    [self doesNotRecognizeSelector:_cmd];
}

- (void)_encodeNull{
    // overridden in subclasses
    [self doesNotRecognizeSelector:_cmd];
}

- (void)_encodeCustomObject:(id)value{
    ASObject *lastObj = m_currentObjectToSerialize;
    ASObject *obj = m_currentObjectToSerialize = [[[ASObject alloc] init] autorelease];
    
    if (m_serializationStack == nil){
        m_serializationStack = [[NSMutableArray alloc] init];
    }
    [m_serializationStack addObject:m_currentObjectToSerialize];
    
    obj.type = [[self class] classNameForClass:[value class]];
    if (!obj.type) obj.type = [self classNameForClass:[value class]];
    if (!obj.type) obj.type = [value className];
    
    [value encodeWithCoder:self];
    
    m_currentObjectToSerialize = lastObj;
    [m_serializationStack removeLastObject];
    
    if (lastObj == nil){
        [self encodeObject:obj];
    }
}

- (void)_appendBytes:(const void*)bytes length:(NSUInteger)length{
    [self _ensureLength:length];
    uint8_t *chars = (uint8_t *)bytes;
    for (NSUInteger i = 0; i < length; i++)
        m_bytes[m_position++] = chars[i];
}

- (void)_setCollectionWriteContext:(NSObject *)obj{
    if (m_writeStack == nil)
        m_writeStack = [[NSMutableArray alloc] init];
    [m_writeStack addObject:obj];
    m_currentObjectToWrite = obj;
}

- (void)_restoreCollectionWriteContext{
    [m_writeStack removeLastObject];
    m_currentObjectToWrite = [m_writeStack lastObject];
}
@end



@implementation AMF0Archiver

#pragma mark -
#pragma mark Public methods

- (void)encodeUTF:(NSString *)value{
    if (value == nil){
        [self encodeUnsignedShort:0];
        return;
    }
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    if ([data length] > 0xFFFF){
        [self encodeUnsignedInt:[data length]];
    }else{
        [self encodeUnsignedShort:[data length]];
    }
    [self encodeDataObject:data];
}



#pragma mark -
#pragma mark Private methods

- (void)_ensureIntegrityOfSerializedObject{
    if (m_currentObjectToSerialize.data != nil){
        [NSException raise:NSInternalInconsistencyException format:@"The AMF0 data format does \
         not allow externalizable objects (non-keyed archiving)!"];
    }
}

- (void)_encodeString:(NSString *)value omitType:(BOOL)omitType{
    NSData *stringData = [value dataUsingEncoding:NSUTF8StringEncoding];
    if ([stringData length] > 0xFFFF){
        omitType ?: [self encodeUnsignedChar:kAMF0LongStringType];
        [self encodeUnsignedInt:[stringData length]];
    }else{
        omitType ?: [self encodeUnsignedChar:kAMF0StringType];
        [self encodeUnsignedShort:[stringData length]];
    }
    [self encodeDataObject:stringData];
}

- (void)_encodeArray:(NSArray *)value{
    if ([m_objectTable indexOfObjectIdenticalTo:value] != NSNotFound){
        [self encodeUnsignedChar:kAMF0ReferenceType];
        [self encodeUnsignedShort:[m_objectTable indexOfObject:value]];
        return;
    }
    [m_objectTable addObject:value];
    [self encodeUnsignedChar:kAMF0ECMAArrayType];
    [self encodeUnsignedInt:[value count]];
    for (id obj in value){
        if([obj isKindOfClass:[NSDictionary class]]){
            NSDictionary *dic=obj;
            NSArray *keys=dic.allKeys;
            for (NSString *key in keys){
                [self encodeUTF:key];
                [self encodeObject:[dic valueForKey:key]];
            }
        }else{
            [self encodeObject:obj];
        }
    }
    [self encodeUnsignedChar:0x0];
    [self encodeUnsignedChar:0x0];
    [self encodeUnsignedChar:kAMF0ObjectEndType];
}

- (void)_encodeDictionary:(NSDictionary *)value{
    if ([m_objectTable indexOfObjectIdenticalTo:value] != NSNotFound){
        [self encodeUnsignedChar:kAMF0ReferenceType];
        [self encodeUnsignedShort:[m_objectTable indexOfObject:value]];
        return;
    }
    [m_objectTable addObject:value];
    
    // empty ecma arrays won't get parsed properly. seems like a bug to me
    if ([value count] == 0){
        // so we write a generic empty object
        [self encodeUnsignedChar:kAMF0ObjectType];
        [self encodeUnsignedShort:0];
        [self encodeUnsignedChar:kAMF0ObjectEndType];
        return;
    }
    [self encodeUnsignedChar:kAMF0ObjectType];
    //[self encodeUnsignedInt:[value count]];
    // PyAMF does always write 0 instead of length
    // @TODO look how flash handles this
    //[self encodeUnsignedInt:0];
    for (NSString *key in value){
        [self encodeUTF:key];
        [self encodeObject:[value objectForKey:key]];
    }
    [self encodeUnsignedShort:0];
    [self encodeUnsignedChar:kAMF0ObjectEndType];
}

- (void)_encodeASObject:(ASObject *)value{
    if ([m_objectTable indexOfObjectIdenticalTo:value] != NSNotFound){
        [self encodeUnsignedChar:kAMF0ReferenceType];
        [self encodeUnsignedShort:[m_objectTable indexOfObject:value]];
        return;
    }
    [m_objectTable addObject:value];
    if (value.type == nil){
        [self encodeUnsignedChar:kAMF0ObjectType];
        //[self encodeUnsignedShort:0];
    }else{
        [self encodeUnsignedChar:kAMF0TypedObjectType];
        [self _encodeString:value.type omitType:YES];
    }
    for (NSString *key in value.properties){
        [self _encodeString:key omitType:YES];
        [self encodeObject:[value valueForKey:key]];
    }
    [self encodeUnsignedShort:0];
    [self encodeUnsignedChar:kAMF0ObjectEndType];
}

- (void)_encodeNumber:(NSNumber *)value omitType:(BOOL)omitType{
    if ([[value className] isEqualToString:@"__NSCFBoolean"] ||
        [[value className] isEqualToString:@"NSCFBoolean"]){
        if (!omitType)
            [self encodeUnsignedChar:kAMF0BooleanType];
        [self encodeBool:[value boolValue]];
        return;
    }
    if (!omitType)
        [self encodeUnsignedChar:kAMF0NumberType];
    [self encodeDouble:[value doubleValue]];
}

- (void)_encodeDate:(NSDate *)value{
    [self encodeUnsignedChar:kAMF0DateType];
    [self encodeDouble:([value timeIntervalSince1970] * 1000)];
    [self encodeUnsignedShort:([[NSTimeZone localTimeZone] secondsFromGMT] / 60)];
}

- (void)_encodeNull{
    [self encodeUnsignedChar:kAMF0NullType];
}
@end



@implementation AMF3Archiver

- (id)init{
    if (self = [super init]){
        m_stringTable = [[NSMutableArray alloc] init];
        m_traitsTable = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc{
    [m_stringTable release];
    [m_traitsTable release];
    [super dealloc];
}

#pragma mark -
#pragma mark Public methods

- (void)encodeUTF:(NSString *)value{
    if (value == nil){
        [self encodeUnsignedInt29:((0 << 1) | 1)];
        return;
    }
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    [self encodeUnsignedInt29:[data length]];
    [self encodeDataObject:data];
}

- (void)encodeBool:(BOOL)value{
    if (m_currentObjectToSerialize != nil){
        [m_currentObjectToSerialize addObject:[_AMFNumber numberWithNSNumber:
                                               [NSNumber numberWithBool:value]]];
        [self _ensureIntegrityOfSerializedObject];
        return;
    }
    [self encodeUnsignedChar:(value ? 1 : 0)];
}



#pragma mark -
#pragma mark Private methods

- (void)_encodeCustomObject:(id)value{
    if ([value isKindOfClass:[NSData class]])
        [self _encodeData:(NSData *)value];
    else
        [super _encodeCustomObject:value];
}

- (void)_encodeArray:(NSArray *)value{
    [self encodeUnsignedChar:kAMF3ArrayType];
    if ([m_objectTable indexOfObjectIdenticalTo:value] != NSNotFound){
        [self encodeUnsignedInt29:([m_objectTable indexOfObject:value] << 1)];
        return;
    }
    [m_objectTable addObject:value];
    [self encodeUnsignedInt29:(([value count] << 1) | 1)];
    [self encodeUnsignedChar:((0 << 1) | 1)];
    for (NSObject *obj in value){
        [self encodeObject:obj];
    }
}

- (void)_encodeString:(NSString *)value omitType:(BOOL)omitType{
    if (!omitType){
        [self encodeUnsignedChar:kAMF3StringType];
    }
    if (value == nil || [value length] == 0){
        [self encodeUnsignedChar:((0 << 1) | 1)];
        return;
    }
    if ([m_stringTable containsObject:value]){
        [self encodeUnsignedInt29:([m_stringTable indexOfObject:value] << 1)];
        return;
    }
    [m_stringTable addObject:value];
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    [self encodeUnsignedInt29:(([data length] << 1) | 1)];
    [self encodeDataObject:data];
}

- (void)_encodeDictionary:(NSDictionary *)value{
    for (id key in value){
        if ([key isKindOfClass:[NSNumber class]]){
            [self _encodeMixedArray:value];
            return;
        }
    }
    [self _encodeASObject:[ASObject asObjectWithDictionary:value]];
}

- (void)_encodeMixedArray:(NSDictionary *)value{
    [self encodeUnsignedChar:kAMF3ArrayType];
    if ([m_objectTable indexOfObjectIdenticalTo:value] != NSNotFound){
        [self encodeUnsignedInt29:([m_objectTable indexOfObject:value] << 1)];
        return;
    }
    
    NSMutableArray *numericKeys = [[[NSMutableArray alloc] init] autorelease];
    NSMutableArray *stringKeys = [[[NSMutableArray alloc] init] autorelease];
    for (id key in value){
        if ([key isKindOfClass:[NSString class]])
            [stringKeys addObject:key];
        else if ([key isKindOfClass:[NSNumber class]])
            [numericKeys addObject:key];
        else
            [NSException raise:NSInternalInconsistencyException
                        format:@"Cannot encode dictionary with key of class %@", [key className]];
    }
    [self encodeUnsignedInt29:(([numericKeys count] << 1) | 1)];
    for (NSString *key in stringKeys){
        [self _encodeString:key omitType:YES];
        [self encodeObject:[value objectForKey:key]];
    }
    [self encodeUnsignedChar:((0 << 1) | 1)];
    for (NSNumber *key in numericKeys){
        [self encodeObject:[value objectForKey:key]];
    }
}

- (void)_encodeDate:(NSDate *)value{
    [self encodeUnsignedChar:kAMF3DateType];
    if ([m_objectTable indexOfObjectIdenticalTo:value] != NSNotFound){
        [self encodeUnsignedInt29:([m_objectTable indexOfObject:value] << 1)];
        return;
    }
    [m_objectTable addObject:value];
    [self encodeUnsignedInt29:((0 << 1) | 1)];
    [self encodeDouble:([value timeIntervalSince1970] * 1000)];
}

- (void)_encodeData:(NSData *)value{
    if ([m_objectTable indexOfObjectIdenticalTo:value] != NSNotFound){
        [self encodeUnsignedInt29:([m_objectTable indexOfObject:value] << 1)];
        return;
    }
    [m_objectTable addObject:value];
    [self encodeDataObject:value];
}

- (void)_encodeNumber:(NSNumber *)value omitType:(BOOL)omitType{
    if ([[value className] isEqualToString:@"__NSCFBoolean"] || 
        [[value className] isEqualToString:@"NSCFBoolean"]){
        if (omitType){
            [self encodeUnsignedChar:([value boolValue] ? 1 : 0)];
        }else{
            [self encodeUnsignedChar:([value boolValue] ? kAMF3TrueType : kAMF3FalseType)];
        }
        return;
    }
    if (strcmp([value objCType], "f") == 0 || 
        strcmp([value objCType], "d") == 0){
        if (!omitType)
            [self encodeUnsignedChar:kAMF3DoubleType];
        [self encodeDouble:[value doubleValue]];
        return;
    }
    if (!omitType){
        [self encodeUnsignedChar:kAMF3IntegerType];
        [self encodeUnsignedInt29:[value intValue]];
    }else{
        [self encodeInt:[value intValue]];
    }
}

- (void)_encodeASObject:(ASObject *)value{
    [self encodeUnsignedChar:kAMF3ObjectType];
    if ([m_objectTable indexOfObjectIdenticalTo:value] != NSNotFound){
        [self encodeUnsignedInt29:([m_objectTable indexOfObject:value] << 1)];
        return;
    }
    [m_objectTable addObject:value];
    AMF3TraitsInfo *traits = [[[AMF3TraitsInfo alloc] init] autorelease];
    traits.externalizable = value.isExternalizable;
    traits.dynamic = (value.type == nil || [value.type length] == 0);
    traits.count = (traits.dynamic || traits.externalizable ? 0 : [value count]);
    traits.className = value.type;
    traits.properties = (traits.dynamic ? nil : (id)[value.properties allKeys]);
    [self _encodeTraits:traits];
    
    if (value.isExternalizable){
        for (id obj in value.data){
            [self encodeObject:obj];
        }
    }
    
    for (NSString *key in value.properties){
        if (traits.dynamic){
            if (![key isKindOfClass:[NSString class]])
                key = [key description];
            [self _encodeString:key omitType:YES];
        }
        
        NSObject *o = [value.properties objectForKey:key];
        if ([o isKindOfClass:[NSData class]]){
            [self encodeObject:[_AMFPlainData plainDataWithData:(NSData *)o]];
        }else{
            [self encodeObject:o];
        }
    }
    if (traits.dynamic){
        [self encodeUnsignedInt29:((0 << 1) | 1)];
    }
}

- (void)_encodeTraits:(AMF3TraitsInfo *)traits{
    if ([m_traitsTable containsObject:traits]){
        [self encodeUnsignedInt29:(([m_traitsTable indexOfObject:traits] << 2) | 1)];
        return;
    }
    [m_traitsTable addObject:traits];
    uint32_t infoBits = 3;
    if (traits.externalizable) infoBits |= 4;
    if (traits.dynamic) infoBits |= 8;
    infoBits |= (traits.count << 4);
    [self encodeUnsignedInt29:infoBits];
    [self _encodeString:traits.className omitType:YES];
    for (uint32_t i = 0; i < traits.count; i++){
        [self _encodeString:[traits.properties objectAtIndex:i] omitType:YES];
    }
}

- (void)_encodeNull{
    [self encodeUnsignedChar:kAMF3NullType];
}
@end


@implementation _AMFStringData

@synthesize data;

+ (_AMFStringData *)stringDataWithData:(NSData *)theData{
    _AMFStringData *sData = [[_AMFStringData alloc] init];
    sData.data = theData;
    return [sData autorelease];
}

- (void)dealloc{
    [data release];
    [super dealloc];
}
@end

@implementation _AMFPlainData

@synthesize data;

+ (_AMFPlainData *)plainDataWithData:(NSData *)theData{
    _AMFPlainData *pData = [[_AMFPlainData alloc] init];
    pData.data = theData;
    return [pData autorelease];
}

- (void)dealloc{
    [data release];
    [super dealloc];
}
@end

@implementation _AMFNumber

@synthesize value;

+ (_AMFNumber *)numberWithNSNumber:(NSNumber *)number{
    _AMFNumber *num = [[_AMFNumber alloc] init];
    num.value = number;
    return [num autorelease];
}

- (void)dealloc{
    [value release];
    [super dealloc];
}
@end
