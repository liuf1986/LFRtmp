//
//  MainViewController.m
//  LFRtmp
//
//  Created by liuf on 2017/5/8.
//  Copyright © 2017年 liufang. All rights reserved.
//

#import "MainViewController.h"
#import "ViewController.h"
#import "PlayViewController.h"
@interface MainViewController ()

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

#pragma mark actions
-(IBAction)onDidTouchPush:(id)sender{
    ViewController *push=[[ViewController alloc] initWithNibName:@"ViewController" bundle:nil];
    [self.navigationController pushViewController:push animated:YES];
}
-(IBAction)onDidTouchPlay:(id)sender{
    PlayViewController *play=[[PlayViewController alloc] initWithNibName:@"PlayViewController" bundle:nil];
    [self.navigationController pushViewController:play animated:YES];
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
