//
//  NSObject-AMFExtensions.m
//  CocoaAMF
//
//  Created by Marc Bauer on 10.04.09.
//  Copyright 2009 nesiumdotcom. All rights reserved.
//

#import "NSObject-AMFExtensions.h"


@implementation NSObject (AMFExtensions)

+ (NSString *)uuid
{
	CFUUIDRef uuidRef = CFUUIDCreate(NULL);
	CFStringRef uuidStringRef = CFUUIDCreateString(NULL, uuidRef);
	CFRelease(uuidRef);
	return [(NSString *)uuidStringRef autorelease];
}
@end