//
//  reyun.h
//  reyun
//
//  Created by li tao on 14-4-10.
//  Copyright (c) 2014年 li tao. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class CLLocation;
@interface reyun : NSObject <UIAlertViewDelegate, NSURLConnectionDelegate>

//性别
typedef enum {
    m = 0,   //男
    f  = 1,  //女
    o = 2,   //其它
} gender;

typedef enum {
    start = 0,   //开始
    done = 1,    //结束
    fail = 2,    //失败
}questStatus;

// 开启数据统计
+ (void)initWithAppKey:(NSString *)appKey channelID:(NSString*)channelID;
//注册成功后调用
+(void)setRegisterWithAccountID:(NSString *)account andGender:(gender)gender andage:(NSString*)age andServerId:(NSString *)serverId andAccountType:(NSString *)accountType;
//登陆成功后调用
+(void)setLoginWithAccountID:(NSString *)accountId andGender:(gender)gender andage:(NSString*)age andServerId:(NSString *)serverId andlevel:(NSInteger)level;
//付费分析,记录玩家充值的金额
+(void)setPayment:(NSString *)transactionId paymentType:(NSString*)paymentType currentType:(NSString*)currencyType currencyAmount:(float)currencyAmount virtualCoinAmount:(float)virtualCoinAmount iapName:(NSString*)iapName iapAmount:(NSInteger)iapAmount andlevel:(NSInteger)level;
//经济系统，虚拟交易发生之后调用
+(void)setEconomy:(NSString *)itemName andEconomyNumber:(NSInteger)itemAmount andEconomyTotalPrice:(float)itemTotalPrice  andlevel:(NSInteger)level;
//任务分析，用户接受任务或完成任务时调用
+(void)setQuest:(NSString *)questId andTaskState:(questStatus)questStatus andTaskType:(NSString *)questType;
//自定义事件分析
+(void)setEvent:(NSString *)eventName andExtra:(NSDictionary *)extra;
+(NSString*)getDeviceId;
@end


