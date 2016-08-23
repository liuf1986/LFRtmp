//
//  AMF.m
//  CocoaAMF
//
//  Created by Marc Bauer on 23.03.09.
//  Copyright 2009 nesiumdotcom. All rights reserved.
//

#import "AMF.h"

NSString * NSStringFromAMF0Type(AMF0Type type){
	switch (type){
		case kAMF0NumberType:
			return @"AMF0NumberType";
		case kAMF0BooleanType:
			return @"AMF0BooleanType";
		case kAMF0StringType:
			return @"AMF0StringType";
		case kAMF0ObjectType:
			return @"AMF0ObjectType";
		case kAMF0MovieClipType:
			return @"AMF0MovieClipType";
		case kAMF0NullType:
			return @"AMF0NullType";
		case kAMF0UndefinedType:
			return @"AMF0UndefinedType";
		case kAMF0ReferenceType:
			return @"AMF0ReferenceType";
		case kAMF0ECMAArrayType:
			return @"AMF0ECMAArrayType";
		case kAMF0ObjectEndType:
			return @"AMF0ObjectEndType";
		case kAMF0StrictArrayType:
			return @"AMF0StrictArrayType";
		case kAMF0DateType:
			return @"AMF0DateType";
		case kAMF0LongStringType:
			return @"AMF0LongStringType";
		case kAMF0UnsupportedType:
			return @"AMF0UnsupportedType";
		case kAMF0RecordsetType:
			return @"AMF0RecordsetType";
		case kAMF0XMLObjectType:
			return @"AMF0XMLObjectType";
		case kAMF0TypedObjectType:
			return @"AMF0TypedObjectType";
		case kAMF0AVMPlusObjectType:
			return @"AMF0AVMPlusObjectType";
	}
	return @"AMF0 Unknown type!";
}

NSString * NSStringFromAMF3Type(AMF3Type type){
	switch (type){
		case kAMF3UndefinedType:
			return @"AMF3UndefinedType";
		case kAMF3NullType:
			return @"AMF3NullType";
		case kAMF3FalseType:
			return @"AMF3FalseType";
		case kAMF3TrueType:
			return @"AMF3TrueType";
		case kAMF3IntegerType:
			return @"AMF3IntegerType";
		case kAMF3DoubleType:
			return @"AMF3DoubleType";
		case kAMF3StringType:
			return @"AMF3StringType";
		case kAMF3XMLDocType:
			return @"AMF3XMLDocType";
		case kAMF3DateType:
			return @"AMF3DateType";
		case kAMF3ArrayType:
			return @"AMF3ArrayType";
		case kAMF3ObjectType:
			return @"AMF3ObjectType";
		case kAMF3XMLType:
			return @"AMF3XMLType";
		case kAMF3ByteArrayType:
			return @"AMF3ByteArrayType";
	}
	return @"AMF3 Unknown type!";
}

NSString * NSStringFromAMF0TypeForDisplay(AMF0Type type){
	switch (type){
		case kAMF0NumberType:
			return @"Number";
		case kAMF0BooleanType:
			return @"Boolean";
		case kAMF0StringType:
			return @"String";
		case kAMF0ObjectType:
			return @"Object";
		case kAMF0MovieClipType:
			return @"MovieClip";
		case kAMF0NullType:
			return @"Null";
		case kAMF0UndefinedType:
			return @"Undefined";
		case kAMF0ReferenceType:
			return @"Reference";
		case kAMF0ECMAArrayType:
			return @"ECMA Array";
		case kAMF0ObjectEndType:
			return @"Object end";
		case kAMF0StrictArrayType:
			return @"Strict Array";
		case kAMF0DateType:
			return @"Date";
		case kAMF0LongStringType:
			return @"Long String";
		case kAMF0UnsupportedType:
			return @"Unsupported Type";
		case kAMF0RecordsetType:
			return @"Recordset";
		case kAMF0XMLObjectType:
			return @"XML";
		case kAMF0TypedObjectType:
			return @"Typed Object";
		case kAMF0AVMPlusObjectType:
			return @"AVMPlus Object Marker";
	}
	return @"Unknown type";
}

NSString * NSStringFromAMF3TypeForDisplay(AMF3Type type){
	switch (type){
		case kAMF3UndefinedType:
			return @"Undefined";
		case kAMF3NullType:
			return @"Null";
		case kAMF3FalseType:
			return @"Boolean";
		case kAMF3TrueType:
			return @"Boolean";
		case kAMF3IntegerType:
			return @"Integer";
		case kAMF3DoubleType:
			return @"Double";
		case kAMF3StringType:
			return @"String";
		case kAMF3XMLDocType:
			return @"XML Document";
		case kAMF3DateType:
			return @"Date";
		case kAMF3ArrayType:
			return @"Array";
		case kAMF3ObjectType:
			return @"Object";
		case kAMF3XMLType:
			return @"XML";
		case kAMF3ByteArrayType:
			return @"ByteArray";
	}
	return @"Unknown type";
}