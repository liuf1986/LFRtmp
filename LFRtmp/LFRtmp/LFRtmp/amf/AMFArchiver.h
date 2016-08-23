//
//  AMFMutableByteArray.h
//  CocoaAMF
//
//  Created by Marc Bauer on 13.01.09.
//  Copyright 2009 nesiumdotcom. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AMF.h"
#import "AMFUnarchiver.h"
#import "ASObject.h"
#import "FlexDataTypes.h"


@interface AMFArchiver : NSCoder{
	NSMutableData *m_data;
	uint8_t *m_bytes;
	uint32_t m_position;
	NSMutableArray *m_objectTable;
	NSMutableArray *m_serializationStack;
	NSMutableArray *m_writeStack;
	NSMutableDictionary *m_registeredClasses;
	ASObject *m_currentObjectToSerialize;
	NSObject *m_currentObjectToWrite;
}

//--------------------------------------------------------------------------------------------------
//	Usual NSCoder methods
//--------------------------------------------------------------------------------------------------

- (id)initForWritingWithMutableData:(NSMutableData *)data encoding:(AMFEncoding)encoding;
+ (NSData *)archivedDataWithRootObject:(id)rootObject encoding:(AMFEncoding)encoding;
+ (BOOL)archiveRootObject:(id)rootObject encoding:(AMFEncoding)encoding toFile:(NSString *)path;

- (BOOL)allowsKeyedCoding;
- (NSData *)data;
- (NSMutableData *)archiverData;
- (void)encodeRootObject:(id)rootObject;
- (void)setClassName:(NSString *)codedName forClass:(Class)cls;
+ (void)setClassName:(NSString *)codedName forClass:(Class)cls;
- (NSString *)classNameForClass:(Class)cls;
+ (NSString *)classNameForClass:(Class)cls;
+ (void)setOptions:(uint16_t)options;
+ (uint16_t)options;

- (void)encodeBool:(BOOL)value forKey:(NSString *)key;
- (void)encodeDouble:(double)value forKey:(NSString *)key;
- (void)encodeFloat:(float)value forKey:(NSString *)key;
- (void)encodeInt32:(int32_t)value forKey:(NSString *)key;
- (void)encodeInt64:(int64_t)value forKey:(NSString *)key;
- (void)encodeInt:(int)value forKey:(NSString *)key;
- (void)encodeObject:(id)value forKey:(NSString *)key;
- (void)encodeValueOfObjCType:(const char *)valueType at:(const void *)address;

//--------------------------------------------------------------------------------------------------
//	AMF Extensions for writing specific data and serializing externalizable classes
//--------------------------------------------------------------------------------------------------

- (void)encodeBool:(BOOL)value;
- (void)encodeChar:(int8_t)value;
- (void)encodeDouble:(double)value;
- (void)encodeFloat:(float)value;
- (void)encodeInt:(int32_t)value;
- (void)encodeShort:(int16_t)value;
- (void)encodeUnsignedChar:(uint8_t)value;
- (void)encodeUnsignedInt:(uint32_t)value;
- (void)encodeUnsignedShort:(uint16_t)value;
- (void)encodeUnsignedInt29:(int32_t)value;
- (void)encodeDataObject:(NSData *)value;
- (void)encodeMultiByteString:(NSString *)value encoding:(NSStringEncoding)encoding;
- (void)encodeObject:(NSObject *)value;
- (void)encodeUTF:(NSString *)value;
- (void)encodeUTFBytes:(NSString *)value;
@end


@interface AMF0Archiver : AMFArchiver{
	AMFArchiver *m_avmPlusByteArray;
}
@end


@interface AMF3Archiver : AMFArchiver{
	NSMutableArray *m_stringTable;
	NSMutableArray *m_traitsTable;
}
@end