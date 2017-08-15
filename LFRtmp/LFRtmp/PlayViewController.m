//
//  PlayViewController.m
//  LFRtmp
//
//  Created by liuf on 2017/5/8.
//  Copyright © 2017年 liufang. All rights reserved.
//

#import "PlayViewController.h"
#import "LFRtmpPlayer.h"
@interface PlayViewController ()
@property (weak,nonatomic) IBOutlet UIView *preview;
@end

@implementation PlayViewController
{
    LFRtmpPlayer *player;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    player=[[LFRtmpPlayer alloc] initWitPreview:_preview];
    player.urlParser=[[LFRtmpUrlParser alloc] initWithUrl:@"rtmp://live.hkstv.hk.lxdns.com/live/hks" port:1935];
    [player play];
    // Do any additional setup after loading the view from its nib.
}
-(IBAction)quit:(id)sender{
    [player stop];
    [self.navigationController popViewControllerAnimated:YES];
}
-(IBAction)pause:(id)sender{
    [player pause];
}
-(IBAction)resume:(id)sender{
    [player resume];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
