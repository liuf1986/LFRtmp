//
//  LFRtmpUrlParser.m
//  myrtmp
//
//  Created by liuf on 16/7/25.
// 
//

#import "LFRtmpUrlParser.h"

@implementation LFRtmpUrlParser

-(instancetype)initWithUrl:(NSString *)url port:(int)port{
    self=[super init];
    if(self){
        _originalUrl=url;
        _port=port;
        [self parse];
    }
    return self;
}

-(void)parse{
    NSString *praseUrl=nil;
    if([_originalUrl hasPrefix:@"rtmp://"]){
        praseUrl=[_originalUrl substringFromIndex:7];
    }else{
        praseUrl=_originalUrl;
    }
    NSArray *array=[praseUrl componentsSeparatedByString:@"/"];
    if(array.count==3){
        _domain=array[0];
        _appName=array[1];
        _streamName=array[2];
        _tcUrl=[NSString stringWithFormat:@"rtmp://%@/%@",_domain,_appName];
        _isAvailable=YES;
    }
}
@end
