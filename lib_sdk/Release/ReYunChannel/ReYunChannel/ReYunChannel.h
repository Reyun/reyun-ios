//
//  ReYunChannel.h
//  ReYunChannel
//
//  Created by yun on 14/12/17.
//  Copyright (c) 2014年 reyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@interface ReYunChannel : NSObject<UIAlertViewDelegate, NSURLConnectionDelegate>

// 开启数据统计
+ (void)initWithAppId:(NSString *)appId withChannelId:(NSString *)channelId;
//注册成功后调用
+ (void)setRegisterWithAccountID:(NSString *)account;
//登陆成功后调用
+ (void)setLoginWithAccountID:(NSString *)account;
//付费分析,记录玩家充值的金额
+(void)setPayment:(NSString *)transactionId paymentType:(NSString*)paymentType currentType:(NSString*)currencyType currencyAmount:(float)currencyAmount;

//自定义事件分析
+(void)setEvent:(NSString *)eventName ;
@end
