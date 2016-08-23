//
//  AMFDebugUnarchiver.m
//  CocoaAMF
//
//  Created by Marc Bauer on 01.05.09.
//  Copyright 2009 nesiumdotcom. All rights reserved.
//

#import "AMFDebugUnarchiver.h"

@interface AMFUnarchiver ()
- (id)initForReadingWithData:(NSData *)data;
@end

@interface AMF0Unarchiver ()
- (NSObject *)_decodeObjectWithType:(AMF0Type)type;
@end

@interface AMF3Unarchiver ()
- (NSObject *)_decodeObjectWithType:(AMF3Type)type;
@end


@implementation AMFDebugUnarchiver

- (id)initForReadingWithData:(NSData *)data encoding:(AMFEncoding)encoding{
	[[self class] setClass:NULL forClassName:[FlexCommandMessage AMFClassAlias]];
	[[self class] setClass:NULL forClassName:[FlexAcknowledgeMessage AMFClassAlias]];
	[[self class] setClass:NULL forClassName:[FlexRemotingMessage AMFClassAlias]];
	[[self class] setClass:NULL forClassName:[FlexErrorMessage AMFClassAlias]];

	NSZone *temp = [self zone];  // Must not call methods after release
	[self release];              // Placeholder no longer needed
	
	return (AMFDebugUnarchiver *)((encoding == kAMF0Encoding)
		? [[AMF0DebugUnarchiver allocWithZone:temp] initForReadingWithData:data]
		: [[AMF3DebugUnarchiver allocWithZone:temp] initForReadingWithData:data]);
}

@end



@implementation AMF0DebugUnarchiver

- (NSObject *)_decodeObjectWithType:(AMF0Type)type{
	if (type == kAMF0AVMPlusObjectType){
		return [AMFDebugUnarchiver unarchiveObjectWithData:[m_data subdataWithRange:
			(NSRange){m_position, [m_data length] - m_position}] encoding:kAMF3Encoding];
	}else{
		AMFDebugDataNode *node = [[[AMFDebugDataNode alloc] init] autorelease];
		node.version = kAMF0Encoding;
		node.type = type;
		node.data = [super _decodeObjectWithType:type];
		return node;
	}
}
@end


@implementation AMF3DebugUnarchiver

- (NSObject *)_decodeObjectWithType:(AMF3Type)type{
	AMFDebugDataNode *node = [[[AMFDebugDataNode alloc] init] autorelease];
	node.version = kAMF3Encoding;
	node.type = type;
	node.data = [super _decodeObjectWithType:type];
	return node;
}

@end




@implementation AMFDebugDataNode

@synthesize version, type, data, children, name, objectClassName;

- (id)init{
	if (self = [super init]){
		children = nil;
	}
	return self;
}

- (void)setData:(NSObject *)theData{
	NSArray *newChildren = nil;
	if ([theData isMemberOfClass:[ASObject class]]){
		self.objectClassName = [(ASObject *)theData type];
		theData = [(ASObject *)theData properties];
	}else if ([theData isMemberOfClass:[FlexArrayCollection class]]){
		self.objectClassName = @"ArrayCollection";
		newChildren = [(AMFDebugDataNode *)[(FlexArrayCollection *)theData source] children];
		theData = nil;
	}else if ([theData isMemberOfClass:[FlexObjectProxy class]]){
		self.objectClassName = @"ObjectProxy";
		newChildren = [(AMFDebugDataNode *)[(FlexObjectProxy *)theData object] children];
		theData = nil;
	}

	if ([theData isKindOfClass:[NSArray class]]){
		newChildren = [NSMutableArray array];
		int index = 0;
		for (AMFDebugDataNode *node in (NSArray *)theData){
			node.name = [NSString stringWithFormat:@"%d", index++];
			[(NSMutableArray *)newChildren addObject:node];
		}
	}else if ([theData isKindOfClass:[NSDictionary class]]){
		newChildren = [NSMutableArray array];
		for (NSString *key in (NSDictionary *)theData){
			AMFDebugDataNode *node = [(NSDictionary *)theData objectForKey:key];
			node.name = key;
			[(NSMutableArray *)newChildren addObject:node];
		}
	}else if (theData != nil){
		[theData retain];
		[data release];
		data = theData;
		return;
	}
	
	[children release];
	children = [newChildren copy];
}

- (BOOL)hasChildren{
	return [children count] > 0;
}

- (NSUInteger)numChildren{
	return [children count];
}

- (NSString *)AMFClassName{
	if (objectClassName != nil)
		return objectClassName;
	
	return version == kAMF0Encoding 
		? NSStringFromAMF0TypeForDisplay(type) 
		: NSStringFromAMF3TypeForDisplay(type);
}

- (void)dealloc{
	[children release];
	[data release];
	[name release];
	[objectClassName release];
	[super dealloc];
}

- (NSString *)description{
	return [NSString stringWithFormat:@"<%@ = 0x%08x> version: %d type: %@ name: %@ data: %@, children: %@", 
		[self className], (long)self, version, [self AMFClassName], name, data, children];
}

@end