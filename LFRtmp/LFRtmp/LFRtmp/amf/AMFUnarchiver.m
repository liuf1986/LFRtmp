//
//  AMFByteArray.m
//  RSFGameServer
//
//  Created by Marc Bauer on 22.11.08.
//  Copyright 2008 nesiumdotcom. All rights reserved.
//

#import "AMFUnarchiver.h"


@interface AMFUnarchiver ()
- (id)initForReadingWithData:(NSData *)data;

- (void)_ensureLength:(unsigned)length;
- (void)_cannotDecodeType:(const char *)type;
- (id)_objectReferenceAtIndex:(uint32_t)index;
- (NSNumber *)_decodeNumberForKey:(NSString *)key;
@end

@interface AMF0Unarchiver ()
- (NSObject *)_decodeObjectWithType:(AMF0Type)type;
- (NSArray *)_decodeArray;
- (NSObject *)_decodeTypedObject;
- (NSObject *)_decodeASObject:(NSString *)className;
- (NSString *)_decodeLongString;
- (NSObject *)_decodeXML;
- (NSDate *)_decodeDate;
- (NSDictionary *)_decodeECMAArray;
- (NSObject *)_decodeReference;
@end

@interface AMF3Unarchiver ()
- (NSObject *)_decodeObjectWithType:(AMF3Type)type;
- (NSObject *)_decodeASObject;
- (NSObject *)_decodeArray;
- (NSObject *)_decodeXML;
- (NSData *)_decodeByteArray;
- (NSDate *)_decodeDate;
- (AMF3TraitsInfo *)_decodeTraits:(uint32_t)infoBits;
- (NSString *)_stringReferenceAtIndex:(uint32_t)index;
- (AMF3TraitsInfo *)_traitsReferenceAtIndex:(uint32_t)index;
@end



#pragma mark -


@implementation AMFUnarchiver

static NSMutableDictionary *g_registeredClasses = nil;
static BOOL g_defaultClassesRegistered = NO;
static uint16_t g_options = 0;
@synthesize objectEncoding=m_objectEncoding, data=m_data;

#pragma mark -
#pragma mark Initialization & Deallocation

+ (void)initialize{
	if (!g_defaultClassesRegistered){
		[[self class] setClass:[FlexArrayCollection class] 
			forClassName:[FlexArrayCollection AMFClassAlias]];
		[[self class] setClass:[FlexObjectProxy class] 
			forClassName:[FlexObjectProxy AMFClassAlias]];
		[[self class] setClass:[FlexCommandMessage class] 
			forClassName:[FlexCommandMessage AMFClassAlias]];
		[[self class] setClass:[FlexAcknowledgeMessage class] 
			forClassName:[FlexAcknowledgeMessage AMFClassAlias]];
		[[self class] setClass:[FlexRemotingMessage class] 
			forClassName:[FlexRemotingMessage AMFClassAlias]];
		[[self class] setClass:[FlexErrorMessage class] 
			forClassName:[FlexErrorMessage AMFClassAlias]];
		g_defaultClassesRegistered = YES;
	}
}

- (id)initForReadingWithData:(NSData *)data encoding:(AMFEncoding)encoding{
	NSZone *temp = [self zone];  // Must not call methods after release
	[self release];              // Placeholder no longer needed
	return (encoding == kAMF0Encoding)
		? [[AMF0Unarchiver allocWithZone:temp] initForReadingWithData:data]
		: [[AMF3Unarchiver allocWithZone:temp] initForReadingWithData:data];
}

- (id)initForReadingWithData:(NSData *)data{
	if (self = [super init]){
		m_data = [data retain];
		m_bytes = [data bytes];
		m_objectTable = [[NSMutableArray alloc] init];
		m_registeredClasses = [[NSMutableDictionary alloc] init];
		m_currentDeserializedObject = nil;
		m_position = 0;
	}
	return self;
}

+ (id)unarchiveObjectWithData:(NSData *)data encoding:(AMFEncoding)encoding{
	if (data == nil){
		[NSException raise:@"AMFInvalidArchiveOperationException" format:@"Invalid data"];
	}
	AMFUnarchiver *byteArray = [[[self class] alloc] initForReadingWithData:data encoding:encoding];
	id object = [[byteArray decodeObject] retain];
	[byteArray release];
	return [object autorelease];
}

+ (id)unarchiveObjectWithFile:(NSString *)path encoding:(AMFEncoding)encoding{
	NSData *data = [NSData dataWithContentsOfFile:path];
	return [[self class] unarchiveObjectWithData:data encoding:encoding];
}

- (void)dealloc{
	[m_data release];
	[m_objectTable release];
	[m_registeredClasses release];
	[super dealloc];
}



#pragma mark -
#pragma mark Public methods

- (BOOL)allowsKeyedCoding{
	return !(!m_currentDeserializedObject || m_currentDeserializedObject.isExternalizable);
}

- (BOOL)containsValueForKey:(NSString *)key{
	return [m_currentDeserializedObject.properties objectForKey:key] != nil;
}

- (void)finishDecoding{
}

- (NSUInteger)bytesAvailable{
	return [m_data length] - m_position;
}

- (BOOL)isAtEnd{
	return !(m_position < [m_data length]);
}

- (Class)classForClassName:(NSString *)codedName{
	return [m_registeredClasses objectForKey:codedName];
}

+ (Class)classForClassName:(NSString *)codedName{
	return [g_registeredClasses objectForKey:codedName];
}

- (void)setClass:(Class)cls forClassName:(NSString *)codedName{
	if (cls == NULL)
		[m_registeredClasses removeObjectForKey:codedName];
	else
		[m_registeredClasses setObject:cls forKey:codedName];
}

+ (void)setClass:(Class)cls forClassName:(NSString *)codedName{
	if (!g_registeredClasses) g_registeredClasses = [[NSMutableDictionary alloc] init];
	if (cls == NULL)
		[g_registeredClasses removeObjectForKey:codedName];
	else
		[g_registeredClasses setObject:cls forKey:codedName];
}

+ (void)setOptions:(uint16_t)options{
	g_options = options;
}

+ (uint16_t)options{
	return g_options;
}

- (BOOL)decodeBoolForKey:(NSString *)key{
	NSNumber *num = [self _decodeNumberForKey:key];
	if (num) return [num boolValue];
	return NO;
}

- (double)decodeDoubleForKey:(NSString *)key{
	NSNumber *num = [self _decodeNumberForKey:key];
	if (num) return [num doubleValue];
	return 0.0;
}

- (float)decodeFloatForKey:(NSString *)key{
	NSNumber *num = [self _decodeNumberForKey:key];
	if (num) return [num floatValue];
	return 0.0f;
}

- (int32_t)decodeInt32ForKey:(NSString *)key{
	NSNumber *num = [self _decodeNumberForKey:key];
	if (num) return [num intValue];
	return 0;
}

- (int64_t)decodeInt64ForKey:(NSString *)key{
	NSNumber *num = [self _decodeNumberForKey:key];
	if (num) return [num integerValue];
	return 0;
}

- (int)decodeIntForKey:(NSString *)key{
	NSNumber *num = [self _decodeNumberForKey:key];
	if (num) return [num intValue];
	return 0;
}

- (id)decodeObjectForKey:(NSString *)key{
	return [m_currentDeserializedObject.properties objectForKey:key];
}

- (void)decodeValueOfObjCType:(const char *)valueType at:(void *)data{
	switch (*valueType){
		case 'c':{
			int8_t *value = data;
			*value = [self decodeChar];
		}
		break;
		case 'C':{
			uint8_t *value = data;
			*value = [self decodeUnsignedChar];
		}
		break;
		case 'i':{
			int32_t *value = data;
			*value = [self decodeInt];
		}
		break;
		case 'I':{
			uint32_t *value = data;
			*value = [self decodeUnsignedInt];
		}
		break;
		case 's':{
			int16_t *value = data;
			*value = [self decodeShort];
		}
		break;
		case 'S':{
			uint16_t *value = data;
			*value = [self decodeUnsignedShort];
		}
		break;
		case 'f':{
			float *value = data;
			*value = [self decodeFloat];
		}
		break;
		case 'd':{
			double *value = data;
			*value = [self decodeDouble];
		}
		break;
		case 'B':{
			uint8_t *value = data;
			*value = [self decodeUnsignedChar];
		}
		break;
		case '*':{
			const char **cString = data;
			NSString *string = [self decodeUTF];
			*cString = NSZoneMalloc(NSDefaultMallocZone(), 
				[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
			*cString = [string cStringUsingEncoding:NSUTF8StringEncoding];
		}
		break;
		case '@':{
			id *obj = data;
			*obj = [self decodeObject];
		}
		break;
		default:
			[self _cannotDecodeType:valueType];
	}
}

- (BOOL)decodeBool{
	return ([self decodeUnsignedChar] != 0);
}

//- (void)compress;
//- (void)uncompress;

- (int8_t)decodeChar{
	[self _ensureLength:1];
	return (int8_t)m_bytes[m_position++];
}

- (NSData *)decodeBytes:(uint32_t)length{
	[self _ensureLength:length];
	NSData *subdata = [m_data subdataWithRange:(NSRange){m_position, length}];
	m_position += length;
	return subdata;
}

- (double)decodeDouble{
	[self _ensureLength:8];
	uint8_t data[8];
	data[7] = m_bytes[m_position++];
	data[6] = m_bytes[m_position++];
	data[5] = m_bytes[m_position++];
	data[4] = m_bytes[m_position++];
	data[3] = m_bytes[m_position++];
	data[2] = m_bytes[m_position++];
	data[1] = m_bytes[m_position++];
	data[0] = m_bytes[m_position++];
	return *((double *)data);
}

- (float)decodeFloat{
	[self _ensureLength:4];
	uint8_t data[4];
	data[3] = m_bytes[m_position++];
	data[2] = m_bytes[m_position++];
	data[1] = m_bytes[m_position++];
	data[0] = m_bytes[m_position++];
	return *((float *)data);
}

- (int32_t)decodeInt{
	[self _ensureLength:4];
	uint8_t ch1 = m_bytes[m_position++];
	uint8_t ch2 = m_bytes[m_position++];
	uint8_t ch3 = m_bytes[m_position++];
	uint8_t ch4 = m_bytes[m_position++];
	return (ch1 << 24) + (ch2 << 16) + (ch3 << 8) + ch4;
}

- (NSObject *)decodeObject{
	return nil;
}

- (int16_t)decodeShort{
	[self _ensureLength:2];
	int8_t ch1 = m_bytes[m_position++];
	int8_t ch2 = m_bytes[m_position++];
	return (ch1 << 8) + ch2;
}

- (uint8_t)decodeUnsignedChar{
	[self _ensureLength:1];
	return m_bytes[m_position++];
}

- (uint32_t)decodeUnsignedInt{
	[self _ensureLength:4];
	uint8_t ch1 = m_bytes[m_position++];
	uint8_t ch2 = m_bytes[m_position++];
	uint8_t ch3 = m_bytes[m_position++];
	uint8_t ch4 = m_bytes[m_position++];
	return ((ch1 & 0xFF) << 24) | ((ch2 & 0xFF) << 16) | ((ch3 & 0xFF) << 8) | (ch4 & 0xFF);
}

- (uint16_t)decodeUnsignedShort{
	[self _ensureLength:2];
	int8_t ch1 = m_bytes[m_position++];
	int8_t ch2 = m_bytes[m_position++];
	return ((ch1 & 0xFF) << 8) | (ch2 & 0xFF);
}

- (uint32_t)decodeUnsignedInt29{
	uint32_t value;
	uint8_t ch = [self decodeUnsignedChar] & 0xFF;
	
	if (ch < 128){
		return ch;
	}
	
	value = (ch & 0x7F) << 7;
	ch = [self decodeUnsignedChar] & 0xFF;
	if (ch < 128){
		return value | ch;
	}
	
	value = (value | (ch & 0x7F)) << 7;
	ch = [self decodeUnsignedChar] & 0xFF;
	if (ch < 128){
		return value | ch;
	}
	
	value = (value | (ch & 0x7F)) << 8;
	ch = [self decodeUnsignedChar] & 0xFF;
	return value | ch;
}

- (NSString *)decodeUTF{
	return [self decodeUTFBytes:[self decodeUnsignedShort]];
}

- (NSString *)decodeUTFBytes:(uint32_t)length{
	if (length == 0){
		return [NSString string];
	}
	[self _ensureLength:length];
	NSData *stringBytes = [self decodeBytes:length];
	NSString *result = [[NSString alloc] initWithData:stringBytes encoding:NSUTF8StringEncoding];
	if (result == nil){
		result = [[NSString alloc] initWithData:stringBytes encoding:NSISOLatin1StringEncoding];
	}
	return [result autorelease];
}

- (NSString *)decodeMultiByteString:(uint32_t)length encoding:(NSStringEncoding)encoding{
	return [[[NSString alloc] initWithData:[self decodeBytes:length] encoding:encoding] autorelease];
}



#pragma mark -
#pragma mark Private methods

- (NSObject *)_deserializeObject:(ASObject *)object{
	if (!object.type){
		return object;
	}
	NSString *className = object.type;
	
	if (((g_options & AMFUnarchiverUnpackArrayCollection) && 
		[className isEqual:[FlexArrayCollection AMFClassAlias]]) || 
		((g_options & AMFUnarchiverUnpackObjectProxyOption) && 
		[className isEqual:[FlexObjectProxy AMFClassAlias]])){
		return [self decodeObject];
	}
	
	Class cls;
	if (!(cls = [self classForClassName:className])){
		if (!(cls = [[self class] classForClassName:className])){
			if (!(cls = objc_getClass([className cStringUsingEncoding:NSUTF8StringEncoding]))){
				return object;
			}
		}
	}
	ASObject *lastDeserializedObject = m_currentDeserializedObject;
	m_currentDeserializedObject = object;
	NSObject <NSCoding> *desObject = [cls allocWithZone:NULL];
	desObject = [desObject initWithCoder:self];
	desObject = [desObject awakeAfterUsingCoder:self];
	m_currentDeserializedObject = lastDeserializedObject;
	
	return [desObject autorelease];
}

- (NSNumber *)_decodeNumberForKey:(NSString *)key{
	NSNumber *num = [m_currentDeserializedObject.properties objectForKey:key];
	if (![num isKindOfClass:[NSNumber class]]){
		return nil;
	}
	return num;
}

- (void)_ensureLength:(unsigned)length{
	if (m_position + length > [m_data length]){
		[NSException raise:@"NSUnarchiverBadArchiveException"
			format:@"%@ attempt to read beyond length. Position: %d, Requested Length: %d, Total Length: %d", 
			[self className], m_position, length, [m_data length]];
	}
}

- (void)_cannotDecodeType:(const char *)type{
	[NSException raise:@"NSUnarchiverCannotDecodeException"
		format:@"%@ cannot decode type=%s", [self className], type];
}

- (id)_objectReferenceAtIndex:(uint32_t)index{
	if ([m_objectTable count] <= index){
		[NSException raise:@"NSUnarchiverCannotDecodeException" 
			format:@"%@ cannot decode object reference", [self className]];
	}
	return [m_objectTable objectAtIndex:index];
}
@end



#pragma mark -



@implementation AMF0Unarchiver

#pragma mark -
#pragma mark Initialization & Deallocation

- (id)initForReadingWithData:(NSData *)data{
	if (self = [super initForReadingWithData:data]){
		m_objectEncoding = kAMF0Encoding;
	}
	return self;
}

- (void)dealloc{
	[super dealloc];
}



#pragma mark -
#pragma mark Public methods

- (NSObject *)decodeObject{
	AMF0Type type = (AMF0Type)[self decodeUnsignedChar];
	return [self _decodeObjectWithType:type];
}



#pragma mark -
#pragma mark Private methods

- (NSObject *)_decodeObjectWithType:(AMF0Type)type{
	id value = nil;
	switch (type){
		case kAMF0NumberType:
			value = [NSNumber numberWithDouble:[self decodeDouble]];
			break;
			
		case kAMF0BooleanType:
			value = [NSNumber numberWithBool:[self decodeBool]];
			break;
			
		case kAMF0StringType:
			value = [self decodeUTF];
			break;
			
		case kAMF0AVMPlusObjectType:{
			AMFUnarchiver *amf3Unarchiver = [[AMFUnarchiver alloc] 
				initForReadingWithData:[m_data subdataWithRange:
					(NSRange){m_position, [m_data length] - m_position}] 
				encoding:kAMF3Encoding];
			value = [amf3Unarchiver decodeObject];
			m_position += [m_data length] - m_position - [amf3Unarchiver bytesAvailable];
			[amf3Unarchiver release];
			break;
		}
		case kAMF0StrictArrayType:
			value = [self _decodeArray];
			break;
			
		case kAMF0TypedObjectType:
			value = [self _decodeTypedObject];
			break;
			
		case kAMF0LongStringType:
			value = [self _decodeLongString];
			break;
			
		case kAMF0ObjectType:
			value = [self _decodeASObject:nil];
			break;
			
		case kAMF0XMLObjectType:
			value = [self _decodeXML];
			break;
			
		case kAMF0NullType:
			value = [NSNull null];
			break;
			
		case kAMF0DateType:
			value = [self _decodeDate];
			break;
			
		case kAMF0ECMAArrayType:
			value = [self _decodeECMAArray];
			break;
			
		case kAMF0ReferenceType:
			value = [self _decodeReference];
			break;
			
		case kAMF0UndefinedType:
			value = [NSNull null];
			break;
			
		case kAMF0UnsupportedType:
			[self _cannotDecodeType:"Unsupported type"];
			break;
			
		case kAMF0ObjectEndType:
			[self _cannotDecodeType:"Unexpected object end"];
			break;
			
		case kAMF0RecordsetType:
			[self _cannotDecodeType:"Unexpected recordset"];
			break;
			
		default:
			[self _cannotDecodeType:"Unknown type"];
	}
	return value;
}

- (NSArray *)_decodeArray{
	uint32_t size = [self decodeUnsignedInt];
	NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:size];
	[m_objectTable addObject:array];
	for (uint32_t i = 0; i < size; i++){
		NSObject *obj = [self decodeObject];
		if (obj != nil){
			[array addObject:obj];
		}
	}
	[array release];
	return array;
}

- (NSObject *)_decodeTypedObject{
	NSString *className = [self decodeUTF];
	return [self _decodeASObject:className];
}

- (NSObject *)_decodeASObject:(NSString *)className{
	ASObject *object = [[ASObject alloc] init];
	object.type = className;
	[m_objectTable addObject:object];
	
	NSString *propertyName = [self decodeUTF];
	AMF0Type type = [self decodeUnsignedChar];
	while (type != kAMF0ObjectEndType){
		[object setValue:[self _decodeObjectWithType:type] forKey:propertyName];
		propertyName = [self decodeUTF];
		type = [self decodeUnsignedChar];
	}
	
	NSObject *desObject = [self _deserializeObject:object];
	if (desObject == object){
		return [object autorelease];
	}
	[m_objectTable replaceObjectAtIndex:[m_objectTable indexOfObject:object] withObject:desObject];
	[object release];
	return desObject;
}

- (NSString *)_decodeLongString{
	uint32_t length = [self decodeUnsignedInt];
	if (length == 0){
		return [NSString string];
	}
	return [self decodeUTFBytes:length];
}

- (NSObject *)_decodeXML{
	NSString *xmlString = [self _decodeLongString];
	#if TARGET_OS_IPHONE
	return xmlString;
	#else
	NSError *error = nil;
	NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithXMLString:xmlString options:0 
		error:&error] autorelease];
	if (!doc){
		NSLog(@"Error parsing XML. %@", error);
		return xmlString;
	}
	return doc;
	#endif
}

- (NSDate *)_decodeDate{
	NSTimeInterval time = [self decodeDouble];
	// timezone
	[self decodeUnsignedShort];
	return [NSDate dateWithTimeIntervalSince1970:(time / 1000)];
}

- (NSDictionary *)_decodeECMAArray{
	uint32_t size = [self decodeUnsignedInt];
	NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:size];
	[m_objectTable addObject:dict];
	[dict release];
	
	NSString *propertyName = [self decodeUTF];
	AMF0Type type = [self decodeUnsignedChar];
	while (type != kAMF0ObjectEndType){
		[dict setValue:[self _decodeObjectWithType:type] forKey:propertyName];
		propertyName = [self decodeUTF];
		type = [self decodeUnsignedChar];
	}
	return dict;
}

- (NSObject *)_decodeReference{
	uint16_t index = [self decodeUnsignedShort];
	return [self _objectReferenceAtIndex:index];
}

@end



#pragma mark -



@implementation AMF3Unarchiver

#pragma mark -
#pragma mark Initialization & Deallocation

- (id)initForReadingWithData:(NSData *)data{
	if (self = [super initForReadingWithData:data]){
		m_stringTable = [[NSMutableArray alloc] init];
		m_traitsTable = [[NSMutableArray alloc] init];
		m_objectEncoding = kAMF3Encoding;
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



- (NSObject *)decodeObject{
	AMF3Type type = (AMF3Type)[self decodeUnsignedChar];
	return [self _decodeObjectWithType:type];
}

- (NSString *)decodeUTF{
	uint32_t ref = [self decodeUnsignedInt29];
	if ((ref & 1) == 0){
		ref = (ref >> 1);
		return [self _stringReferenceAtIndex:ref];
	}
	uint32_t length = ref >> 1;
	if (length == 0){
		return [NSString string];
	}
	NSString *value = [self decodeUTFBytes:length];
	[m_stringTable addObject:value];
	return value;
}



#pragma mark -
#pragma mark Private methods

- (NSString *)_stringReferenceAtIndex:(uint32_t)index{
	if ([m_stringTable count] <= index){
		[NSException raise:@"NSUnarchiverCannotDecodeException" 
			format:@"%@ cannot decode string reference", [self className]];
	}
	return [m_stringTable objectAtIndex:index];
}

- (AMF3TraitsInfo *)_traitsReferenceAtIndex:(uint32_t)index{
	if ([m_traitsTable count] <= index){
		[NSException raise:@"NSUnarchiverCannotDecodeException" 
			format:@"%@ cannot decode traits reference", [self className]];
	}
	return [m_traitsTable objectAtIndex:index];
}

- (NSObject *)_decodeObjectWithType:(AMF3Type)type{
	//NSLog(@"%@ (%d)", NSStringFromAMF3Type(type), type);
	id value = nil;
	switch (type){
		case kAMF3StringType:
			value = [self decodeUTF];
			break;
		
		case kAMF3ObjectType:
			value = [self _decodeASObject];
			break;
			
		case kAMF3ArrayType:
			value = [self _decodeArray];
			break;
			
		case kAMF3FalseType:
			value = [NSNumber numberWithBool:NO];
			break;
			
		case kAMF3TrueType:
			value = [NSNumber numberWithBool:YES];
			break;
			
		case kAMF3IntegerType:{
			int32_t intValue = [self decodeUnsignedInt29];
			intValue = (intValue << 3) >> 3;
			value = [NSNumber numberWithInt:intValue];
			break;
		}
			
		case kAMF3DoubleType:
			value = [NSNumber numberWithDouble:[self decodeDouble]];
			break;
			
		case kAMF3UndefinedType:
			return [NSNull null];
			break;
			
		case kAMF3NullType:
			return [NSNull null];
			break;
			
		case kAMF3XMLType:
		case kAMF3XMLDocType:
			value = [self _decodeXML];
			break;
			
		case kAMF3DateType:
			value = [self _decodeDate];
			break;
			
		case kAMF3ByteArrayType:
			value = [self _decodeByteArray];
			break;
			
		default:
			[self _cannotDecodeType:"Unknown type"];
			break;
	}
	//NSLog(@"%@", value);
	return value;
}

- (NSObject *)_decodeASObject{
	uint32_t ref = [self decodeUnsignedInt29];
	if ((ref & 1) == 0){
		ref = (ref >> 1);
		return [self _objectReferenceAtIndex:ref];
	}
	
	AMF3TraitsInfo *traitsInfo = [self _decodeTraits:ref];
	NSObject *object;
	if (traitsInfo.className && [traitsInfo.className length] > 0){
		object = [[ASObject alloc] init];
		[(ASObject *)object setType:traitsInfo.className];
		[(ASObject *)object setIsExternalizable:traitsInfo.externalizable];
	}else{
		object = [[NSMutableDictionary alloc] init];
	}
	[m_objectTable addObject:object];
	
	NSString *key;
	for (key in traitsInfo.properties){
		[object setValue:[self decodeObject] forKey:key];
	}
	
	if (traitsInfo.dynamic){
		key = [self decodeUTF];
		while (key != nil && [key length] > 0){
			[object setValue:[self decodeObject] forKey:key];
			key = [self decodeUTF];
		}
	}
	
	if (![object isMemberOfClass:[ASObject class]]){
		NSDictionary *dictCopy = [object copy];
		[object release];
		return [dictCopy autorelease];
	}
	
	NSObject *desObject = [self _deserializeObject:(ASObject *)object];
	if (desObject == object){
		return [object autorelease];
	}
	[m_objectTable replaceObjectAtIndex:[m_objectTable indexOfObject:object] withObject:desObject];
	[object release];
	return desObject;
}

- (NSObject *)_decodeArray{
	uint32_t ref = [self decodeUnsignedInt29];
	
	if ((ref & 1) == 0){
		ref = (ref >> 1);
		return [self _objectReferenceAtIndex:ref];
	}
	
	uint32_t length = (ref >> 1);
	NSObject *array = nil;
	for (;;){
		NSString *name = [self decodeUTF];
		if (name == nil || [name length] == 0){
			break;
		}
		
		if (array == nil){
			array = [NSMutableDictionary dictionary];
			[m_objectTable addObject:array];
		}
		[(NSMutableDictionary *)array setObject:[self decodeObject] forKey:name];
	}
	
	if (array == nil){
		array = [NSMutableArray array];
		[m_objectTable addObject:array];
		for (uint32_t i = 0; i < length; i++){
			[(NSMutableArray *)array addObject:[self decodeObject]];
		}
	}else{
		for (uint32_t i = 0; i < length; i++){
			[(NSMutableDictionary *)array setObject:[self decodeObject] 
				forKey:[NSNumber numberWithInt:i]];
		}
	}
	
	return array;
}

- (AMF3TraitsInfo *)_decodeTraits:(uint32_t)infoBits{
	if ((infoBits & 3) == 1){
		infoBits = (infoBits >> 2);
		return [self _traitsReferenceAtIndex:infoBits];
	}
	BOOL externalizable = (infoBits & 4) == 4;
	BOOL dynamic = (infoBits & 8) == 8;
	NSUInteger count = infoBits >> 4;
	NSString *className = [self decodeUTF];
	
	AMF3TraitsInfo *info = [[AMF3TraitsInfo alloc] init];
	info.className = className;
	info.dynamic = dynamic;
	info.externalizable = externalizable;
	info.count = count;
	while (count--){
		[info addProperty:[self decodeUTF]];
	}
	[m_traitsTable addObject:info];
	[info release];
	return info;
}

- (NSObject *)_decodeXML{
	NSString *xmlString = [self decodeUTF];
	#if TARGET_OS_IPHONE
	return xmlString;
	#else
	NSError *error = nil;
	NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithXMLString:xmlString options:0 
		error:&error] autorelease];
	if (!doc){
		NSLog(@"Error parsing XML. %@", error);
		return xmlString;
	}
	return doc;
	#endif
}

- (NSData *)_decodeByteArray{
	uint32_t ref = [self decodeUnsignedInt29];
	if ((ref & 1) == 0){
		ref = (ref >> 1);
		return [self _objectReferenceAtIndex:ref];
	}
	uint32_t length = (ref >> 1);
	NSData *data = [self decodeBytes:length];
	[m_objectTable addObject:data];
	return data;
}

- (NSDate *)_decodeDate{
	uint32_t ref = [self decodeUnsignedInt29];
	if ((ref & 1) == 0){
		ref = (ref >> 1);
		return [self _objectReferenceAtIndex:ref];
	}
	NSTimeInterval time = [self decodeDouble];
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:(time / 1000)];
	[m_objectTable addObject:date];
	return date;
}

@end



#pragma mark -



@implementation AMF3TraitsInfo

@synthesize className=m_className;
@synthesize dynamic=m_dynamic;
@synthesize externalizable=m_externalizable;
@synthesize count=m_count;
@synthesize properties=m_properties;


#pragma mark -
#pragma mark Initialization & Deallocation

- (id)init{
	if (self = [super init]){
		m_properties = [[NSMutableArray alloc] init];
		m_dynamic = NO;
		m_externalizable = NO;
	}
	return self;
}

- (void)dealloc{
	[m_className release];
	[m_properties release];
	[super dealloc];
}



#pragma mark -
#pragma mark Public methods

- (void)addProperty:(NSString *)property{
	[m_properties addObject:property];
}

- (BOOL)isEqual:(id)anObject{
	if ([anObject class] != [self class]){
		return NO;
	}
	AMF3TraitsInfo *traits = (AMF3TraitsInfo *)anObject;
	BOOL classNameIdentical = m_className == nil 
		? traits.className == nil 
		: [traits.className isEqualToString:m_className];
	BOOL propertiesIdentical = m_properties == nil 
		? traits.properties == nil 
		: [traits.properties isEqualToArray:m_properties];
	if (classNameIdentical &&
		traits.dynamic == m_dynamic &&
		traits.externalizable == m_externalizable &&
		[traits count] == m_count &&
		propertiesIdentical){
		return YES;
	}
	return NO;
}

- (NSString *)description{
	return [NSString stringWithFormat:@"<%@ = 0x%08X | className: %@ | dynamic: %d \
| externalizable: %d | count: %d>", 
		[self class], (long)self, m_className, m_dynamic, m_externalizable, m_count];
}

@end