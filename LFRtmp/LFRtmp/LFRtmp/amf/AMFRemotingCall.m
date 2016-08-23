//
//  AMFRemotingCall.m
//  CocoaAMF
//
//  Created by Marc Bauer on 10.01.09.
//  Copyright 2009 nesiumdotcom. All rights reserved.
//

#import "AMFRemotingCall.h"

@interface AMFRemotingCall (Private)
- (NSString *)_nextResponseURI;
- (void)_cleanup;
@end


@implementation AMFRemotingCall

@synthesize service=m_service, method=m_method, arguments=m_arguments, amfVersion=m_amfVersion, 
	delegate=m_delegate;

static uint32_t g_responseCount = 1;

#pragma mark -
#pragma mark Initialization & Deallocation

- (id)init{
	if (self = [super init]){
		m_receivedData = nil;
		m_connection = nil;
		m_delegate = nil;
		m_isLoading = NO;
		m_amfVersion = kAMF3Encoding;
		m_error = nil;
		m_amfHeaders = nil;
		
		m_request = [[NSMutableURLRequest alloc] init];
		[m_request setHTTPMethod:@"POST"];
		[m_request setValue:@"application/x-amf" forHTTPHeaderField:@"Content-Type"];
		[m_request setValue:@"CocoaAMF" forHTTPHeaderField:@"User-Agent"];
	}
	return self;
}

- (id)initWithURL:(NSURL *)url service:(NSString *)service method:(NSString *)method 
	arguments:(NSObject *)arguments{
	if (self = [self init]){
		self.URL = url;
		self.service = service;
		self.method = method;
		self.arguments = arguments;
	}
	return self;
}

+ (AMFRemotingCall *)remotingCallWithURL:(NSURL *)url service:(NSString *)service 
	method:(NSString *)method arguments:(NSObject *)arguments{
	AMFRemotingCall *remotingCall = [[AMFRemotingCall alloc] initWithURL:url service:service 
		method:method arguments:arguments];
	return [remotingCall autorelease];
}

- (void)dealloc{
	[m_connection release];
	[m_request release];
	[m_service release];
	[m_method release];
	[m_arguments release];
	[m_error release];
	[m_amfHeaders release];
	[super dealloc];
}



#pragma mark -
#pragma mark Public methods

- (void)start{
	if (m_isLoading){
		return;
	}

	AMFActionMessage *message = [[AMFActionMessage alloc] init];
	message.version = m_amfVersion;
	NSString *targetURI = @"null";
	if (m_service != nil && m_method != nil)
		targetURI = [NSString stringWithFormat:@"%@.%@", m_service, m_method];
	[message addBodyWithTargetURI:targetURI responseURI:[self _nextResponseURI] data:m_arguments];
	if (m_amfHeaders != nil)
		message.headers = [m_amfHeaders allValues];
	
	[m_request setHTTPBody:[message data]];
	[message release];
	
	m_error = nil;
	m_receivedData = [[NSMutableData alloc] init];
	m_connection = [[NSURLConnection alloc] initWithRequest:m_request delegate:self];
	
	m_isLoading = YES;
}

- (void)setURL:(NSURL *)url{
	[m_request setURL:url];
}

- (NSURL *)URL{
	return [m_request URL];
}

- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field{
	[m_request addValue:value forHTTPHeaderField:field];
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field{
	[m_request setValue:value forHTTPHeaderField:field];
}

- (NSString *)valueForHTTPHeaderField:(NSString *)field{
	return [m_request valueForHTTPHeaderField:field];
}

- (void)setValue:(NSObject *)value forAMFHeaderField:(NSString *)field 
	mustUnderstand:(BOOL)mustUnderstand{
	if (m_amfHeaders == nil)
		m_amfHeaders = [[NSMutableDictionary alloc] init];
	[m_amfHeaders setValue:[AMFMessageHeader messageHeaderWithName:field data:value 
		mustUnderstand:mustUnderstand] forKey:field];
}



#pragma mark -
#pragma mark Private methods

- (NSString *)_nextResponseURI{
	return [NSString stringWithFormat:@"/%d", g_responseCount++];
}

- (void)_cleanup{
	[m_connection release];
	m_connection = nil;
	[m_receivedData release];
	m_receivedData = nil;
	[m_error release];
	m_error = nil;
}



#pragma mark -
#pragma mark NSURLConnection Delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{	
	if ([[[(NSHTTPURLResponse *)response allHeaderFields] objectForKey:@"Content-Type"] 
		rangeOfString:@"application/x-amf"].location == NSNotFound){
		m_error = [[NSError errorWithDomain:kAMFRemotingCallErrorDomain 
			code:kAMFInvalidResponseErrorCode userInfo:[NSDictionary dictionaryWithObject:
				[NSString stringWithFormat:@"The server returned no application/x-amf data at URL %@.", 
					[[response URL] absoluteString]] forKey:NSLocalizedDescriptionKey]] retain];
	}else if ([(NSHTTPURLResponse *)response statusCode] != 200){
		m_error = [[NSError errorWithDomain:kAMFRemotingCallErrorDomain 
			code:kAMFServerErrorErrorCode userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
				[NSString stringWithFormat:@"The server returned status code %d at URL %@.", 
					[(NSHTTPURLResponse *)response statusCode], [[response URL] absoluteString]], 
				NSLocalizedDescriptionKey, [NSNumber numberWithInt:
					[(NSHTTPURLResponse *)response statusCode]], kAMFServerStatusCodeKey, nil]] retain];
	}
	
	if ([m_delegate respondsToSelector:@selector(remotingCall:didReceiveResponse:)]){
		((void (*)(id, SEL, id,id))(void *)objc_msgSend)(m_delegate, @selector(remotingCall:didReceiveResponse:), self, response);
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
	[m_receivedData appendData:data];
	if ([m_delegate respondsToSelector:@selector(remotingCall:didReceiveData:)]){
		((void (*)(id, SEL, id,id))(void *)objc_msgSend)(m_delegate, @selector(remotingCall:didReceiveData:), self, data);
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection{
	if (!m_error && [m_receivedData length] == 0){
		m_error = [[NSError errorWithDomain:kAMFRemotingCallErrorDomain 
			code:kAMFInvalidResponseErrorCode userInfo:[NSDictionary dictionaryWithObject:
				@"The server returned zero bytes of data" forKey:NSLocalizedDescriptionKey]] retain];
	}
	
	if (m_error){
		((void (*)(id, SEL, id,id))(void *)objc_msgSend)(m_delegate, @selector(remotingCall:didFailWithError:), self, m_error);
	}else{
		AMFActionMessage *message = [[AMFActionMessage alloc] initWithData:m_receivedData];
		NSObject *data = [[message.bodies objectAtIndex:0] data];
		((void (*)(id, SEL, id,id))(void *)objc_msgSend)(m_delegate, @selector(remotingCallDidFinishLoading:receivedObject:),
			self, data);
		[message release];
	}
	[self _cleanup];
	m_isLoading = NO;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
	((void (*)(id, SEL, id,id))(void *)objc_msgSend)(m_delegate, @selector(remotingCall:didFailWithError:), self, error);
	[self _cleanup];
	m_isLoading = NO;
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request 
	redirectResponse:(NSURLResponse *)redirectResponse{
	if ([m_delegate respondsToSelector:@selector(remotingCall:willSendRequest:redirectResponse:)]){
        return ((NSURLRequest* (*)(id, SEL, id,id,id))(void *)objc_msgSend)(m_delegate,
                                                                            @selector(remotingCall:willSendRequest:redirectResponse:), self, request,
                                                                            redirectResponse);
	}
	return request;
}

@end