//
//  Person.m
//  JSWeb
//
//  Created by mac on 2017/12/18.
//  Copyright © 2017年 Jess. All rights reserved.
//

#import "Person.h"

@implementation Person

- (void)play{
    NSLog(@"%@玩",_name);
}

- (void)playWithGame:(NSString *)game time:(NSString *)time{
    NSLog(@"%@在%@玩%@",_name,time,game);
}

@end
