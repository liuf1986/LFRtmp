//
//  ViewController.m
//  myrtmp
//
//  Created by liuf on 16/7/15.
// 
//

#import "ViewController.h"
#import "LFRtmpService.h"
#import "FilterSelectModalView.h"
@interface ViewController ()<LFRtmpServiceDelegate,FilterSelectModalViewDelegate>

@property (weak,nonatomic) IBOutlet UILabel *statusLabel;
@property (weak,nonatomic) IBOutlet UIView  *preveiw;
@property (weak,nonatomic) IBOutlet UIView  *controlView;
@property (weak,nonatomic) IBOutlet UIButton *palyButton;
@property (strong,nonatomic) IBOutlet UISlider *slider;
@end

@implementation ViewController
{
    LFRtmpService *rtmpService;
    UIButton *_statusBtn;
    BOOL _isOpenFlash;
    BOOL _isStarted;
    BOOL _isFrontCamera;
    FilterSelectModalView *_filterSelectView;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    _isFrontCamera=YES;
    rtmpService=[[LFRtmpService alloc] initWitConfig:[LFVideoConfig defaultConfig]
                                         audioConfig:[LFAudioConfig defaultConfig]
                                             preview:_preveiw];
    rtmpService.delegate=self;
    [self.view addSubview:_statusBtn];
    _filterSelectView=[[NSBundle mainBundle] loadNibNamed:@"FilterSelectModalView" owner:nil options:nil][0];
    _filterSelectView.delegate=self;
}

-(void)addLogo{
    UIImageView *logoView=[[UIImageView alloc] initWithFrame:CGRectMake(50, 56, 80, 17)];
    logoView.image=[UIImage imageNamed:@"logo"];
    [rtmpService setLogoView:logoView];
}
-(IBAction)toggleCapture:(id)sender{
    if(!_isStarted){
        [self addLogo];
        [_palyButton setImage:[UIImage imageNamed:@"capture_stop_button"] forState:(UIControlStateNormal)];
        [rtmpService start:@"rtmp://userpush.livecdn.cditv.cn/userlive/liuf" port:1935];
    }else{
        [_palyButton setImage:[UIImage imageNamed:@"capture_button"] forState:(UIControlStateNormal)];
        _statusLabel.text=@"未连接";
        [rtmpService stop];
    }
    _isStarted=!_isStarted;
}
-(IBAction)toggleScreen:(id)sender{
    if(!_isStarted){
        if([rtmpService isLandscape]){
            UIInterfaceOrientation orientation=[[UIApplication sharedApplication] statusBarOrientation];
            if(orientation==UIInterfaceOrientationPortrait||orientation==UIInterfaceOrientationPortraitUpsideDown){
                [rtmpService setVideoConfig:[[LFVideoConfig alloc]
                                             init:LFVideoConfigQuality_Default isLandscape:NO]];
                [rtmpService setOrientation:orientation];
            }
            
        }else{
            UIInterfaceOrientation orientation=[[UIApplication sharedApplication] statusBarOrientation];
            if(orientation==UIInterfaceOrientationLandscapeLeft||orientation==UIInterfaceOrientationLandscapeRight){
                [rtmpService setVideoConfig:[[LFVideoConfig alloc]
                                             init:LFVideoConfigQuality_Default isLandscape:YES]];
                [rtmpService setOrientation:orientation];
            }
        }
    }
}

-(IBAction)toggleFlash:(id)sender{
    [rtmpService setIsOpenFlash:!rtmpService.isOpenFlash];
}

-(IBAction)toggleCamera:(id)sender{
    if(_isFrontCamera){
        [rtmpService setDevicePosition:AVCaptureDevicePositionBack];
    }else{
         [rtmpService setDevicePosition:AVCaptureDevicePositionFront];
    }
    _isFrontCamera=!_isFrontCamera;
}

-(IBAction)back:(id)sender{
    [rtmpService quit];
}

-(IBAction)selectFilter:(id)sender{
    [_filterSelectView show:NO];
    
}
#pragma mark slider actions

- (IBAction)beginScrubbing:(id)sender{
    
}
- (IBAction)scrub:(id)sender{
    [rtmpService setZoomScale:[_slider value]];
}
- (IBAction)endScrubbing:(id)sender{
    
}

#pragma mark FilterSelectModalViewDelegate

-(void)onDidTouchFilter:(int)filterType{
    [rtmpService setFilterType:filterType];
}

#pragma mark LFRtmpServiceDelegate
/**
 *  当rtmp状态发生改变时的回调
 *
 *  @param status 状态描述符
 */
-(void)onRtmpStatusChange:(LFRTMPStatus)status{
    switch (status) {
        case LFRTMPStatusConnectionFail:
        {
            [_statusLabel setText:@"连接失败!重连中..."];
        }
            break;
        case LFRTMPStatusPublishSending:
        {
            [_statusLabel setText:@"流发布中"];
        }
            break;
        case LFRTMPStatusPublishReady:
        {
           [_statusLabel setText:@"流发布成功，开始推流"];
        }
            break;
        case LFRTMPStatusPublishFail:
        {
           [_statusLabel setText:@"流发布失败，restart"];
           [rtmpService reStart];
        }
            break;
        default:
            break;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
