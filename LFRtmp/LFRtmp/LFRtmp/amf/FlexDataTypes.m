//
//  AMFFlexDataTypes.m
//  CocoaAMF
//
//  Created by Marc Bauer on 23.03.09.
//  Copyright 2009 nesiumdotcom. All rights reserved.
//

#import "FlexDataTypes.h"


@implementation FlexArrayCollection

@synthesize source;

+ (NSString *)AMFClassAlias{
	return @"flex.messaging.io.ArrayCollection";
}

- (id)initWithSource:(NSArray *)obj{
	if (self = [super init]){
		self.source = obj;
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)coder{
	if (self = [super init]){
		self.source = [coder decodeObject];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder{
	[coder encodeObject:source];
}

- (BOOL)isEqual:(id)obj{
	return [obj isMemberOfClass:[self class]] && 
		[source isEqual:[obj source]];
}

- (void)dealloc{
	[source release];
	[super dealloc];
}

- (NSUInteger)count{
	return [source count];
}

- (NSString *)description{
	return [NSString stringWithFormat:@"<%@ = 0x%08x> %@", [self className], (long)self, source];
}

@end


#pragma mark -


@implementation FlexObjectProxy

@synthesize object;

+ (NSString *)AMFClassAlias{
	return @"flex.messaging.io.ObjectProxy";
}

- (id)initWithObject:(NSObject *)obj{
	if (self = [super init]){
		self.object = obj;
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)coder{
	if (self = [super init]){
		self.object = [coder decodeObject];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder{
	[coder encodeObject:object];
}

- (BOOL)isEqual:(id)obj{
	return [obj isMemberOfClass:[self class]] && 
		[object isEqual:[obj object]];
}

- (void)dealloc{
	[object release];
	[super dealloc];
}
@end


#pragma mark -


@implementation FlexAbstractMessage

@synthesize body, clientId, destination, headers, messageId, timeToLive, timestamp;

+ (NSString *)AMFClassAlias{
	return @"flex.messaging.messages.AbstractMessage";
}

- (id)init{
	if (self = [super init]){
		self.messageId = [NSObject uuid];
		self.clientId = [NSObject uuid];
		self.timestamp = [[NSDate date] timeIntervalSince1970];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)coder{
	if (self = [super init]){
		self.body = [coder decodeObjectForKey:@"body"];
		self.clientId = [coder decodeObjectForKey:@"clientId"];
		self.destination = [coder decodeObjectForKey:@"destination"];
		self.headers = [coder decodeObjectForKey:@"headers"];
		self.messageId = [coder decodeObjectForKey:@"messageId"];
		self.timeToLive = [coder decodeInt32ForKey:@"timeToLive"] / 1000;
		self.timestamp = [coder decodeDoubleForKey:@"timestamp"] / 1000;
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder{
	[coder encodeObject:body forKey:@"body"];
	[coder encodeObject:clientId forKey:@"clientId"];
	[coder encodeObject:destination forKey:@"destination"];
	[coder encodeObject:headers forKey:@"headers"];
	[coder encodeObject:messageId forKey:@"messageId"];
	[coder encodeDouble:(timeToLive * 1000) forKey:@"timeToLive"];
	[coder encodeDouble:(timestamp * 1000) forKey:@"timestamp"];
}

- (NSString *)description{
	return [NSString stringWithFormat:@"<%@ = 0x%08x> clientId: %@, destination: %@, messageId: %@ \
timeToLive: %f, timestamp: %f,\nheaders:\n%@,\nbody:\n%@", [self className], (long)self, clientId,
	destination, messageId, timeToLive, timestamp, headers, body];
}

- (void)dealloc{
	[body release];
	[clientId release];
	[destination release];
	[headers release];
	[messageId release];
	[super dealloc];
}

@end


#pragma mark -


@implementation FlexAsyncMessage

@synthesize correlationId;

+ (NSString *)AMFClassAlias{
	return @"flex.messaging.messages.AsyncMessage";
}

- (id)initWithCoder:(NSCoder *)coder{
	if (self = [super initWithCoder:coder]){
		self.correlationId = [coder decodeObjectForKey:@"correlationId"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder{
	[super encodeWithCoder:coder];
	[coder encodeObject:correlationId forKey:@"correlationId"];
}

- (void)dealloc{
	[correlationId release];
	[super dealloc];
}

@end



#pragma mark -


@implementation FlexCommandMessage

@synthesize operation;

+ (NSString *)AMFClassAlias{
	return @"flex.messaging.messages.CommandMessage";
}

- (id)initWithCoder:(NSCoder *)coder{
	if (self = [super initWithCoder:coder]){
		self.operation = [coder decodeIntForKey:@"operation"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder{
	[super encodeWithCoder:coder];
	[coder encodeInt:operation forKey:@"operation"];
}

@end


#pragma mark -


@implementation FlexAcknowledgeMessage

+ (NSString *)AMFClassAlias{
	return @"flex.messaging.messages.AcknowledgeMessage";
}

@end


#pragma mark -


@implementation FlexErrorMessage

@synthesize extendedData, faultCode, faultDetail, faultString, rootCause;

+ (NSString *)AMFClassAlias{
	return @"flex.messaging.messages.ErrorMessage";
}

+ (FlexErrorMessage *)errorMessageWithError:(NSError *)error{
	FlexErrorMessage *errorMsg = [[FlexErrorMessage alloc] init];
	errorMsg.faultCode = [NSString stringWithFormat:@"%d", [error code]];
	errorMsg.faultString = [error domain];
	errorMsg.faultDetail = [error localizedDescription];
	errorMsg.extendedData = [error userInfo];
	return [errorMsg autorelease];
}

- (id)initWithCoder:(NSCoder *)coder{
	if (self = [super initWithCoder:coder]){
		self.extendedData = [coder decodeObjectForKey:@"extendedData"];
		self.faultCode = [coder decodeObjectForKey:@"faultCode"];
		self.faultDetail = [coder decodeObjectForKey:@"faultDetail"];
		self.faultString = [coder decodeObjectForKey:@"faultString"];
		self.rootCause = [coder decodeObjectForKey:@"rootCause"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder{
	[super encodeWithCoder:coder];
	[coder encodeObject:extendedData forKey:@"extendedData"];
	[coder encodeObject:faultCode forKey:@"faultCode"];
	[coder encodeObject:faultDetail forKey:@"faultDetail"];
	[coder encodeObject:faultString forKey:@"faultString"];
	[coder encodeObject:rootCause forKey:@"rootCause"];
}

- (void)dealloc{
	[extendedData release];
	[faultCode release];
	[faultDetail release];
	[faultString release];
	[rootCause release];
	[super dealloc];
}

- (NSString *)description{
	return [NSString stringWithFormat:@"<%@ = 0x%08x> faultCode: %@, faultDetail: %@, faultString: %@", 
		[self className], (long)self, faultCode, faultDetail, faultString];
}

@end


#pragma mark -


@implementation FlexRemotingMessage

@synthesize operation, source;

+ (NSString *)AMFClassAlias{
	return @"flex.messaging.messages.RemotingMessage";
}

- (id)initWithCoder:(NSCoder *)coder{
	if (self = [super initWithCoder:coder]){
		self.operation = [coder decodeObjectForKey:@"operation"];
		self.source = [coder decodeObjectForKey:@"source"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder{
	[super encodeWithCoder:coder];
	[coder encodeObject:operation forKey:@"operation"];
	[coder encodeObject:source forKey:@"source"];
}

- (void)dealloc{
	[operation release];
	[source release];
	[super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ = 0x%08x> clientId: %@, destination: %@, operation: %@, messageId: %@ \
timeToLive: %f, timestamp: %f,\nheaders:\n%@,\nbody:\n%@", [self className], (long)self, clientId, 
	destination, operation, messageId, timeToLive, timestamp, headers, body];
}

@end