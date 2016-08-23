//
//  FilterSelectModalView.m
//  myrtmp
//
//  Created by liuf on 16/8/18.
// 
//

//屏幕高度
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height

//屏幕宽度
#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define TopCollIdentifier @"TopCollIdentifier"
#import "FilterSelectModalView.h"

@implementation FilterSelectModalView
{
    __weak IBOutlet UICollectionView *_collectionView;
}

-(void)awakeFromNib{
    [_collectionView registerClass:[UICollectionViewCell class]
               forCellWithReuseIdentifier:TopCollIdentifier];
}
-(void)show:(BOOL)isAnimation{

    self.frame=CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
    [super show:NO];
}

#pragma mark UICollectionViewDelegate
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return CGSizeMake(80, 100);
}
-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    return UIEdgeInsetsMake(0, 0, 0, 0);
}
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    
    return 1;
}
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return 5;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell=nil;
    cell=[collectionView dequeueReusableCellWithReuseIdentifier:TopCollIdentifier
                                                   forIndexPath:indexPath];
    [cell.contentView.subviews enumerateObjectsUsingBlock:^(UIView *view,
                                                            NSUInteger idx,
                                                            BOOL *stop) {
        
        [view removeFromSuperview];
        view=nil;
        
    }];
    UILabel *label=[[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 100)];
    label.font=[UIFont systemFontOfSize:15];
    label.textColor=[UIColor redColor];
    label.textAlignment=NSTextAlignmentCenter;
    if(indexPath.row==0){
        label.text=@"美颜";
    }else if(indexPath.row==1){
        label.text=@"原始";
    }else if(indexPath.row==2){
        label.text=@"变形";
    }else if(indexPath.row==3){
        label.text=@"挤压";
    }else if(indexPath.row==4){
        label.text=@"管道";
    }
    
    [cell.contentView addSubview:label];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    if(_delegate){
        [_delegate onDidTouchFilter:(int)indexPath.row+1];
    }
    [self hide:NO];
}

@end
