//
//  FilterSelectModalView.h
//  myrtmp
//
//  Created by liuf on 16/8/18.
// 
//

#import "ModalWindowView.h"

@protocol FilterSelectModalViewDelegate <NSObject>

-(void)onDidTouchFilter:(int)filterType;

@end

@interface FilterSelectModalView : ModalWindowView

@property (assign,nonatomic) id<FilterSelectModalViewDelegate>delegate;

@end
