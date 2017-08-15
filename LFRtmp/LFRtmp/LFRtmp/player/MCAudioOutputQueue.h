//
//  MCAudioOutputQueue
//  MCAudioQueue
//
//  Created by Chengyin on 14-7-27.
//  Copyright (c) 2014年 Chengyin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface MCAudioOutputQueue : NSObject

@property (nonatomic,assign,readonly) BOOL available;
@property (nonatomic,assign,readonly) AudioStreamBasicDescription format;
@property (nonatomic,assign) float volume;
@property (nonatomic,assign) UInt32 bufferSize;
@property (nonatomic,assign,readonly) BOOL isRunning;

/**
 *  return playedTime of audioqueue, return invalidPlayedTime when error occurs.
 */
@property (nonatomic,readonly) NSTimeInterval playedTime;

- (instancetype)initWithFormat:(AudioStreamBasicDescription)format bufferSize:(UInt32)bufferSize macgicCookie:(NSData *)macgicCookie;

/**
 *  Play audio data, data length must be less than bufferSize.
 *  Will block current thread until the buffer is consumed.
 *
 *  @param data               data
 *  @param packetCount        packet count
 *  @param packetDescriptions packet desccriptions
 *
 *  @return whether successfully played
 */
- (BOOL)playData:(NSData *)data packetCount:(UInt32)packetCount packetDescriptions:(AudioStreamPacketDescription *)packetDescriptions isEof:(BOOL)isEof;

/**
 *  pause & resume
 *
 */
- (BOOL)pause;
- (BOOL)resume;

/**
 *  Stop audioqueue
 *
 *  @param immediately if pass YES, the queue will immediately be stopped,
 *                     if pass NO, the queue will be stopped after all buffers are flushed (the same job as -flush).
 *
 *  @return whether is audioqueue successfully stopped
 */
- (BOOL)stop:(BOOL)immediately;

/**
 *  reset queue
 *  Use when seeking.
 *
 *  @return whether is audioqueue successfully reseted
 */
- (BOOL)reset;

/**
 *  flush data
 *  Use when audio data reaches eof
 *  if -stop:NO is called this method will do nothing
 *
 *  @return whether is audioqueue successfully flushed
 */
- (BOOL)flush;

- (BOOL)setProperty:(AudioQueuePropertyID)propertyID dataSize:(UInt32)dataSize data:(const void *)data error:(NSError **)outError;
- (BOOL)getProperty:(AudioQueuePropertyID)propertyID dataSize:(UInt32 *)dataSize data:(void *)data error:(NSError **)outError;
- (BOOL)setParameter:(AudioQueueParameterID)parameterId value:(AudioQueueParameterValue)value error:(NSError **)outError;
- (BOOL)getParameter:(AudioQueueParameterID)parameterId value:(AudioQueueParameterValue *)value error:(NSError **)outError;
@end
