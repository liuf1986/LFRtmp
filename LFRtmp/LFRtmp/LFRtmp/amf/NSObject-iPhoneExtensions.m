//
//  NSObject-iPhoneExtensions.m
//  CocoaAMF-iPhone
//
//  Created by Marc Bauer on 11.01.09.
//  Copyright 2009 nesiumdotcom. All rights reserved.
//

#import "NSObject-iPhoneExtensions.h"


@implementation NSObject (iPhoneExtensions)

- (NSString *)className
{
	return NSStringFromClass([self class]);
}

@end