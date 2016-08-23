//
//  AMFActionMessage.h
//  SimpleHTTPServer
//
//  Created by Marc Bauer on 12.10.08.
//  Copyright 2008 nesiumdotcom. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AMF.h"
#import "AMFArchiver.h"
#import "AMFUnarchiver.h"
#import "AMFDebugUnarchiver.h"

@class AMFMessageHeader, AMFMessageBody;

@interface AMFActionMessage : NSObject{
	AMFEncoding m_version;
	NSMutableArray *m_headers;
	NSMutableArray *m_bodies;
	BOOL m_useDebugUnarchiver;
}
@property (nonatomic, assign) AMFEncoding version;
@property (nonatomic, retain) NSArray *headers;
@property (nonatomic, retain) NSArray *bodies;

- (id)initWithData:(NSData *)data;
- (id)initWithDataUsingDebugUnarchiver:(NSData *)data;
- (NSData *)data;

- (NSUInteger)messagesCount;
- (AMFMessageBody *)bodyAtIndex:(NSUInteger)index;
- (AMFMessageHeader *)headerAtIndex:(NSUInteger)index;

- (void)addBodyWithTargetURI:(NSString *)targetURI responseURI:(NSString *)responseURI data:(id)data;
- (void)addHeaderWithName:(NSString *)name mustUnderstand:(BOOL)mustUnderstand data:(id)data;

- (void)mergeActionMessage:(AMFActionMessage *)message;
@end


@interface AMFMessageHeader : NSObject{
	NSString *m_name;
	BOOL m_mustUnderstand;
	NSObject *m_data;
}
@property (nonatomic, retain) NSString *name;
@property (nonatomic, assign) BOOL mustUnderstand;
@property (nonatomic, retain) NSObject *data;

+ (AMFMessageHeader *)messageHeaderWithName:(NSString *)name data:(NSObject *)data 
	mustUnderstand:(BOOL)mustUnderstand;
@end


@interface AMFMessageBody : NSObject{
	NSString *m_targetURI;
	NSString *m_responseURI;
	NSObject *m_data;
}
@property (nonatomic, retain) NSString *targetURI;
@property (nonatomic, retain) NSString *responseURI;
@property (nonatomic, retain) NSObject *data;
@end