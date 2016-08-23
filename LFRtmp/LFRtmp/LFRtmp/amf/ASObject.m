//
//  ASObject.m
//  CocoaAMF
//
//  Created by Marc Bauer on 09.10.08.
//  Copyright 2008 nesiumdotcom. All rights reserved.
//

#import "ASObject.h"


@implementation ASObject

@synthesize type=m_type, properties=m_properties, isExternalizable=m_isExternalizable, data=m_data;

#pragma mark -
#pragma mark Initialization & Deallocation

- (id)init{
	if (self = [super init]){
		m_properties = nil;
		m_data = nil;
		m_type = nil;
		m_isExternalizable = NO;
	}
	return self;
}

+ (ASObject *)asObjectWithDictionary:(NSDictionary *)dict{
	ASObject *obj = [[[ASObject alloc] init] autorelease];
	NSMutableDictionary *mutableCopy = [dict mutableCopy];
	obj.properties = mutableCopy;
	[mutableCopy release];
	return obj;
}

- (void)dealloc{
	[m_type release];
	[m_properties release];
	[m_data release];
	[super dealloc];
}

- (BOOL)isEqual:(id)obj{
	if (![obj isKindOfClass:[ASObject class]]){
		return NO;
	}
	ASObject *asObj = (ASObject *)obj;
	return ((asObj.type == nil && m_type == nil) || [asObj.type isEqual:m_type]) && 
		asObj.isExternalizable == m_isExternalizable && 
		(m_isExternalizable 
			? [asObj.data isEqual:m_data] 
			: [asObj.properties isEqual:m_properties]);
}



#pragma mark -
#pragma mark Public methods

- (void)setValue:(id)value forKey:(NSString *)key{
	if (m_properties == nil)
		m_properties = [[NSMutableDictionary alloc] init];
	[m_properties setValue:value forKey:key];
}

- (id)valueForKey:(NSString *)key{
	return [m_properties valueForKey:key];
}

- (void)addObject:(id)obj{
	if (m_data == nil){
		m_data = [[NSMutableArray alloc] init];
		m_isExternalizable = YES;
	}
	[m_data addObject:obj];
}

- (NSUInteger)count{
	return m_isExternalizable ? [m_data count] : [m_properties count];
}

- (NSString *)description{
	return [NSString stringWithFormat:@"<%@ = 0x%08X | type: %@>\n%@\ndata: %@", 
		[self class], (long)self, m_type, m_properties, m_data];
}

@end