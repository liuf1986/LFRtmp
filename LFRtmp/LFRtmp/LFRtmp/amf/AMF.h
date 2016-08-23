/*
 *  AMF.h
 *  SimpleHTTPServer
 *
 *  Created by Marc Bauer on 12.10.08.
 *  Copyright 2008 nesiumdotcom. All rights reserved.
 *
 */

#import <Foundation/Foundation.h>

typedef enum{
	kAMF0Encoding = 0x0,
	kAMF3Encoding = 0x3
} AMFEncoding;

typedef enum{
	kAMF0NumberType = 0x0,
	kAMF0BooleanType = 0x1,
	kAMF0StringType = 0x2,
	kAMF0ObjectType = 0x3,
	kAMF0MovieClipType = 0x4,
	kAMF0NullType = 0x5,
	kAMF0UndefinedType = 0x6,
	kAMF0ReferenceType = 0x7,
	kAMF0ECMAArrayType = 0x8,
	kAMF0ObjectEndType = 0x9,
	kAMF0StrictArrayType = 0xA,
	kAMF0DateType = 0xB,
	kAMF0LongStringType = 0xC,
	kAMF0UnsupportedType = 0xD,
	kAMF0RecordsetType = 0xE,
	kAMF0XMLObjectType = 0xF,
	kAMF0TypedObjectType = 0x10,
	kAMF0AVMPlusObjectType = 0x11
} AMF0Type;

typedef enum{
	kAMF3UndefinedType = 0x0,
	kAMF3NullType = 0x1,
	kAMF3FalseType = 0x2,
	kAMF3TrueType = 0x3,
	kAMF3IntegerType = 0x4,
	kAMF3DoubleType = 0x5,
	kAMF3StringType = 0x6,
	kAMF3XMLDocType = 0x7,
	kAMF3DateType = 0x8,
	kAMF3ArrayType = 0x9,
	kAMF3ObjectType = 0xA,
	kAMF3XMLType = 0xB,
	kAMF3ByteArrayType = 0xC
} AMF3Type;

enum{
	AMFUnarchiverUnpackArrayCollection = 0x1,
	AMFUnarchiverUnpackObjectProxyOption = 0x2
};

enum{
	AMFArchiverPackArrayOption = 0x1 // converts an array to an ArrayCollection
};

NSString * NSStringFromAMF0Type(AMF0Type type);
NSString * NSStringFromAMF3Type(AMF3Type type);
NSString * NSStringFromAMF0TypeForDisplay(AMF0Type type);
NSString * NSStringFromAMF3TypeForDisplay(AMF3Type type);

#define kAMFCoreErrorDomain @"AMFCoreErrorDomain"
#define kAMFGatewayErrorDomain @"AMFGatewayErrorDomain"

typedef enum{
	kAMFErrorInvalidRequest = 1, 
	kAMFErrorServiceNotFound = 2, 
	kAMFErrorMethodNotFound = 3, 
	kAMFErrorArgumentMismatch = 4,
	kAMFErrorInvalidArguments = 5
} AMFErrorCode;