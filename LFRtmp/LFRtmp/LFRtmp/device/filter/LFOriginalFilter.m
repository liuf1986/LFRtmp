//
//  LFOriginalFilter.m
//  myrtmp
//
//  Created by liuf on 16/8/3.
//
//
#import "LFOriginalFilter.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const LFOriginalFilterString = SHADER_STRING
                                                       (
    varying highp vec2 textureCoordinate;

    uniform sampler2D inputImageTexture;

    void main(){
    lowp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);

    gl_FragColor = vec4((textureColor.rgb), textureColor.w);
}

                                                       );
#else
NSString *const LFOriginalFilterString = SHADER_STRING
                                                      (
    varying vec2 textureCoordinate;

    uniform sampler2D inputImageTexture;

    void main(){
    vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);

    gl_FragColor = vec4((textureColor.rgb), textureColor.w);
}

                                                      );
#endif

@implementation LFOriginalFilter

- (id)init{
    self = [super initWithFragmentShaderFromString:LFOriginalFilterString];
    return self;
}
@end

