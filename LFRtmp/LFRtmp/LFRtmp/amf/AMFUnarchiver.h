//
//  AMFByteArray.h
//  RSFGameServer
//
//  Created by Marc Bauer on 22.11.08.
//  Copyright 2008 nesiumdotcom. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "AMF.h"
#import "ASObject.h"
#import "FlexDataTypes.h"

#if TARGET_OS_IPHONE
#import "NSObject-iPhoneExtensions.h"
#endif

#define AMFInvalidArchiveOperationException @"AMFInvalidArchiveOperationException"

@interface AMFUnarchiver : NSCoder{
	NSData *m_data;
	const uint8_t *m_bytes;
	uint32_t m_position;
	AMFEncoding m_objectEncoding;
	NSMutableDictionary *m_registeredClasses;
	NSMutableArray *m_objectTable;
	ASObject *m_currentDeserializedObject;
}
@property (nonatomic, readonly) AMFEncoding objectEncoding;
@property (nonatomic, readonly) NSData *data;

//--------------------------------------------------------------------------------------------------
//	Usual NSCoder methods
//--------------------------------------------------------------------------------------------------

- (id)initForReadingWithData:(NSData *)data encoding:(AMFEncoding)encoding;
+ (id)unarchiveObjectWithData:(NSData *)data encoding:(AMFEncoding)encoding;
+ (id)unarchiveObjectWithFile:(NSString *)path encoding:(AMFEncoding)encoding;

- (BOOL)allowsKeyedCoding;
- (void)finishDecoding;
- (NSUInteger)bytesAvailable;
- (BOOL)isAtEnd;
- (Class)classForClassName:(NSString *)codedName;
+ (Class)classForClassName:(NSString *)codedName;
- (void)setClass:(Class)cls forClassName:(NSString *)codedName;
+ (void)setClass:(Class)cls forClassName:(NSString *)codedName;
+ (void)setOptions:(uint16_t)options;
+ (uint16_t)options;
- (BOOL)containsValueForKey:(NSString *)key;

- (BOOL)decodeBoolForKey:(NSString *)key;
- (double)decodeDoubleForKey:(NSString *)key;
- (float)decodeFloatForKey:(NSString *)key;
- (int32_t)decodeInt32ForKey:(NSString *)key;
- (int64_t)decodeInt64ForKey:(NSString *)key;
- (int)decodeIntForKey:(NSString *)key;
- (id)decodeObjectForKey:(NSString *)key;
- (void)decodeValueOfObjCType:(const char *)valueType at:(void *)data;

//--------------------------------------------------------------------------------------------------
//	AMF Extensions for reading specific data and deserializing externalizable classes
//--------------------------------------------------------------------------------------------------

//- (void)compress;
// - (void)uncompress;

- (BOOL)decodeBool;
- (int8_t)decodeChar;
- (double)decodeDouble;
- (float)decodeFloat;
- (int32_t)decodeInt;
- (int16_t)decodeShort;
- (uint8_t)decodeUnsignedChar;
- (uint32_t)decodeUnsignedInt;
- (uint16_t)decodeUnsignedShort;
- (uint32_t)decodeUnsignedInt29;
- (NSData *)decodeBytes:(uint32_t)length;
- (NSString *)decodeMultiByteString:(uint32_t)length encoding:(NSStringEncoding)encoding;
- (NSObject *)decodeObject;
- (NSString *)decodeUTF;
- (NSString *)decodeUTFBytes:(uint32_t)length;
@end



@interface AMF0Unarchiver : AMFUnarchiver{
}
@end



@interface AMF3Unarchiver : AMFUnarchiver{
	NSMutableArray *m_stringTable;
	NSMutableArray *m_traitsTable;
}
@end



@interface AMF3TraitsInfo : NSObject{
	NSString *m_className;
	BOOL m_dynamic;
	BOOL m_externalizable;
	NSUInteger m_count;
	NSMutableArray *m_properties;
}
@property (nonatomic, retain) NSString *className;
@property (nonatomic, assign) BOOL dynamic;
@property (nonatomic, assign) BOOL externalizable;
@property (nonatomic, assign) NSUInteger count;
@property (nonatomic, retain) NSMutableArray *properties;

- (void)addProperty:(NSString *)property;
@end