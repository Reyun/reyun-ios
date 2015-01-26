//
//  reyun.m
//  reyun
//
//  Created by li tao on 14-4-10.
//  Copyright (c) 2014年 li tao. All rights reserved.
//

//
//
//  Created by chen reyun on 13-3-5.
//  Copyright (c) 2013年 reyun. All rights reserved.
//

#import "reyun.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <AdSupport/ASIdentifierManager.h>

//#import "GetIP.h"
//#import "NdUncaughtExceptionHandlerSDK.h"
#import "OpenUDIDSDK.h"
#import "RYReachabilitysdk.h"//判断网络
#import <ifaddrs.h>
#include <arpa/inet.h>
//#import "KeychainItemWrapper.h"

#import "RYDataBase.h"
#import "RYSSKeychain.h"
#import "RYSBJSON.h"

#define MAXADDRS 255
#define AppName [[[NSBundle mainBundle] infoDictionary] objectForKey:@"Bundle name"]
#define APP_VERSION [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey]
#define checkversionurl @"http://log.reyun.com"         //热云网服务器新
//#define checkversionurl @"http://192.168.120.45:8080"     //zhen

reyun* aClick = NULL;
NSInteger _groupId;
NSMutableData *_receivedData;
long long  _marginTime=0;
static BOOL _haveURL=NO;
NSURLConnection *_ServerConnection;
NSInteger arrayCount;
NSInteger sendCatchMsg;
@implementation reyun
typedef enum {
    INSTALL = 0,            //安装时发送
    REGISTER  = 1,          //注册时发送
    DAU = 2,                //每日发送
    COUNTER = 3,            //用户自定义发送
    DEVICE = 4,             //设备信息
    SESSION = 5,            //会话状态报送。
    EXCEPTION = 6,          //异常报送。
    HEARTBEAD = 7,          //心跳发送。
    UPDATEVERSION = 8,      //版本控制。
    STARTUP = 9,            //每次启动都发送
    LOGGEDIN = 10,          //登陆时发送
    EVENT=11,               //event发送
    PAYMENT=12,             //payment
    ECONOMY=13,            //economy
    TASK=14,                //task
    REGED=15,               //reged
    GETTIME=16              //gettime
    
} CommandFunc;
-(void)dealloc
{
    [_ServerConnection release];
    [_receivedData release];
    [super dealloc];
}
+(reyun *)sharedClick{//是否为第一次 安装
    if (!aClick) {
        aClick = [[reyun alloc] init];
    }
    return aClick;
}
-(id)init
{//初始化 并且获取 服务器时间
    self=[super init];
    if (self) {
        [self getServersTime];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive)name:UIApplicationWillResignActiveNotification object:nil];
    }
    return self;
}
- (void)applicationWillResignActive
{
    [self performSelector:@selector(sendURLConnectionAgain) withObject:nil afterDelay:0];
}
+(void)setChannelID:(NSString*)channelID{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    [installInfo setObject:channelID forKey:@"channelId"];
    //[installInfo synchronize];
    
}

// 检查渠道商
-(NSString*)GetChannel_Id{
    NSString* chanelID = nil;
    NSUserDefaults* installInfo = [NSUserDefaults standardUserDefaults];
    //  当渠道有值的时候可以显示
    NSString* channelLocal = [installInfo objectForKey:@"channelId"];
    if([channelLocal length]>0){
        chanelID = channelLocal;
    }
    else{
        chanelID = @"unknown";
    }
    return chanelID;
}

//开启安装模式
+ (void)InstallMessage{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    NSInteger alreadinstall = [[installInfo objectForKey:@"alreadyinstal"] intValue];
    if (alreadinstall !=1) {
        [installInfo setInteger:1 forKey:@"alreadyinstal"];
        [[reyun sharedClick] SendBODYMessage:INSTALL];
    }
}

#pragma mark 调用——————————————————
+ (void)initWithAppId:(NSString *)appId channelID:(NSString*)channelID{
    
    
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];//缓存本地临时文件
    
    [installInfo setObject:appId forKey:@"InstallappKeys"];
    [installInfo setObject:channelID forKey:@"channelId"];//往里面存

    [self InstallMessage];//安装调用
    
    //每次启动时调用；包括第一次启动。
    
    [[reyun sharedClick] SendBODYMessage:STARTUP];
    [[reyun sharedClick] heartBeatSendMessage:TRUE];//
    //应用启动的时候调用。如果有session的缓存数据就发送。用户成功登录之后，记录一个session开始时间，在游戏HOME或关闭的时候记录一个session结束时间，同时计算出开始和结束时间之间的间隔的秒数，待下次startup时报送。
}
#pragma mark 获得用户信息接口——————————————
//注册成功后调用
+(void)setRegisterWithAccountID:(NSString *)account andGender:(gender)gender andage:(NSString*)age andServerId:(NSString *)serverId andAccountType:(NSString *)accountType{
    
    [[reyun sharedClick] setAccountid:account];//账号
    [[reyun sharedClick] setGender:gender];//性别:f女,m男,o其他
    [[reyun sharedClick] setBirthday:age];//生日,格式yyyy-MM-DD
    [[reyun sharedClick] setServerid:serverId];//服务器id
    [[reyun sharedClick] setAccountType:accountType];//账号类型
    
    [[reyun sharedClick] SendBODYMessage:REGED];//
}



//登陆成功后调用
+(void)setLoginWithAccountID:(NSString *)accountId andGender:(gender)gender andage:(NSString*)age andServerId:(NSString *)serverId andlevel:(NSInteger)level{
    [[reyun sharedClick] setAccountid:accountId];//账号
    [[reyun sharedClick] setGender:gender];//性别
    [[reyun sharedClick] setBirthday:age];//年龄
    [[reyun sharedClick] setServerid:serverId];//服务器id
    [reyun setLevel:[NSString stringWithFormat:@"%d",level]];//等级
    [[reyun sharedClick] SendBODYMessage:LOGGEDIN];
     
}
//经济系统，虚拟交易发生之后调用
+(void)setEconomy:(NSString *)itemName andEconomyNumber:(NSInteger)itemAmount andEconomyTotalPrice:(float)itemTotalPrice  andlevel:(NSInteger)level{
    [[reyun sharedClick] setTradingNum:[NSString stringWithFormat:@"%d",itemAmount]]; //交易数量
    [[reyun sharedClick] setTradingTotalPrice:itemTotalPrice]; //交易金额
    [[reyun sharedClick] setTradingName:itemName];//交易名称
    [reyun setLevel:[NSString stringWithFormat:@"%d",level]];//等级
    [[reyun sharedClick] SendBODYMessage:ECONOMY];
}
//任务分析，用户接受任务或完成任务时调用
+(void)setQuest:(NSString *)questId andTaskState:(questStatus)questStatus andTaskType:(NSString *)questType{
    [[reyun sharedClick] setTaskId:questId];//任务代号
    [[reyun sharedClick] setTaskState:questStatus]; //接受：start； 完成：done 失败、fail
    [[reyun sharedClick] setTaskType:questType];//新手引导任务。(new:新手任务；main:
    [[reyun sharedClick] SendBODYMessage:TASK];
}
//自定义事件分析
+(void)setEvent:(NSString *)eventName andExtra:(NSDictionary *)extra{
    [[reyun sharedClick] setEventName:eventName];//事件名称
    [[reyun sharedClick] setExtra:extra]; //自定义键值对
    [[reyun sharedClick] SendBODYMessage:EVENT];
}

-(void)setAccountName:(NSString*)accountName{
    if (0==[accountName length]) {
        NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
        [installInfo setObject:@"unknown" forKey:@"accountid"];//unknown游客
    }else{
        NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
        [installInfo setObject:accountName forKey:@"accountid"];//visitors游客
    }
}
//获得用户信息，注册账号
-(void)setAccountid:(NSString *)accountid{
    if (0==[accountid length]) {
        NSLog(@"Account is empty");
        NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
        [installInfo setObject:@"visitors" forKey:@"accountid"];//visitors游客
    }else{
        NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
        [installInfo setObject:accountid forKey:@"accountid"];
        //[installInfo synchronize];
    }
}
//用户注册状态，如微博注册、qq注册等
-(void)setAccountType:(NSString *)accountType{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    if (0==[accountType length]) {
        [installInfo setObject:@"unknown" forKey:@"accountType"];
    }else{
        [installInfo setObject:accountType forKey:@"accountType"];
    }
    //[installInfo synchronize];
    
}

+(void)setLevel:(NSString *)level{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    if (0==[level length]) {
        [installInfo setObject:@"-1" forKey:@"level"];
    }else{
        [installInfo setObject:level forKey:@"level"];
    }
    //[installInfo synchronize];
}
//注：f 代表女，m 代表男，o 代表其它
-(void)setGender:(gender)gender{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    if (gender == m) {
        [installInfo setObject:@"m" forKey:@"gender"];
    }else if(gender == f){
        [installInfo setObject:@"f" forKey:@"gender"];
    }else if(gender == o){
        [installInfo setObject:@"o" forKey:@"gender"];
    }
    else{
        [installInfo setObject:@"unknown" forKey:@"gender"];
    }
}
-(void)setBirthday:(NSString *)birthday{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    if (0==[birthday length]) {
        [installInfo setObject:@"-1" forKey:@"birthday"];
        
    }else{
        [installInfo setObject:birthday forKey:@"birthday"];
    }
    //[installInfo synchronize];
}
-(void)setServerid:(NSString *)serverid{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    if (0==[serverid length]) {
        [installInfo setObject:@"unknown" forKey:@"serverid"];
        
    }else{
        [installInfo setObject:serverid forKey:@"serverid"];
    }
    //[installInfo synchronize];
}
//event
-(void)setEventName:(NSString *)eventName{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    if (0==[eventName length]) {
        [installInfo setObject:@"unknown" forKey:@"eventName"];
        
    }else{
        [installInfo setObject:eventName forKey:@"eventName"];
    }
    //[installInfo synchronize];
}
-(void)setLocation:(NSString *)location{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    if (0==[location length]) {
        [installInfo setObject:@"unknown" forKey:@"location"];
        
    }else{
        [installInfo setObject:location forKey:@"location"];
    }
    //[installInfo synchronize];
}
-(void)setExtra:(NSDictionary *)dict{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    [installInfo setObject:dict forKey:@"extra"];
    //[installInfo synchronize];
    
}
+(void)setPayment:(NSString *)transactionId paymentType:(NSString*)paymentType currentType:(NSString*)currencyType currencyAmount:(float)currencyAmount virtualCoinAmount:(float)virtualCoinAmount iapName:(NSString*)iapName iapAmount:(NSInteger)iapAmount andlevel:(NSInteger)level{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    if ([transactionId length]>0) {
        [installInfo setValue:transactionId forKey:@"transactionId"];
    }
    else{
        [installInfo setValue:@"unknown" forKey:@"transactionId"];
    }
    if ([paymentType length]>0) {
        [installInfo setValue:paymentType forKey:@"paymentType"];
    }
    else{
        [installInfo setValue:@"unknown" forKey:@"paymentType"];
    }
    if ([currencyType length]>0) {
        [installInfo setValue:currencyType forKey:@"currenctyType"];
    }
    else{
        [installInfo setValue:@"unknown" forKey:@"currenctyType"];
    }
    if ([iapName length]>0) {
        [installInfo setValue:iapName forKey:@"iapName"];
    }
    else{
        [installInfo setValue:@"unknown" forKey:@"iapName"];
    }
    if (level>=0) {
        NSString* levelStr = [NSString stringWithFormat:@"%d",level];
        [installInfo setValue:levelStr forKey:@"level"];
    }
    NSString* currencyAmountStr = [NSString stringWithFormat:@"%f",currencyAmount];
    [installInfo setValue:currencyAmountStr forKey:@"currencyAmount"];
    NSString* virtualCointAmountStr = [NSString stringWithFormat:@"%f",virtualCoinAmount];
    [installInfo setObject:virtualCointAmountStr forKey:@"virtualCoinAmount"];
    NSString* iapAmountStr = [NSString stringWithFormat:@"%d",iapAmount];
    [installInfo setObject:iapAmountStr forKey:@"iapAmount"];
    [[reyun sharedClick] SendBODYMessage:PAYMENT];
}
//用户在此次虚拟交易中的，交易的物品的数量
-(void)setTradingNum:(NSString *)num{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    if ([num intValue]!=0) {
        [installInfo setObject:num forKey:@"num"];
        //[installInfo synchronize];
    }else{
        [installInfo setObject:@"0" forKey:@"num"];
        //[installInfo synchronize];
    }
}
//用户虚拟交易对象的名称
-(void)setTradingName:(NSString *)name{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    if (0==[name length]) {
        [installInfo setObject:@"unknown" forKey:@"name"];
    }else{
        [installInfo setObject:name forKey:@"name"];
    }
    //[installInfo synchronize];
}
//用户此次虚拟交易过程中的交易额
-(void)setTradingTotalPrice:(float)totalPrice{
    if (totalPrice<0.000001&&totalPrice>-0.000001) {
        totalPrice=0;
    }
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    [installInfo setObject:[NSNumber numberWithFloat:totalPrice] forKey:@"totalPrice"];
    //[installInfo synchronize];
}
//用户此次虚拟交易的类型
-(void)setTradingType:(NSString *)type{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    if (0==[type length]) {
        [installInfo setObject:@"unknown" forKey:@"type"];
    }else{
        [installInfo setObject:type forKey:@"type"];
    }
    //[installInfo synchronize];
}
//任务的id
-(void)setTaskId:(NSString *)taskId{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    if (0==[taskId length]) {
        [installInfo setObject:@"unknown" forKey:@"taskId"];
    }else{
        [installInfo setObject:taskId forKey:@"taskId"];
    }
    //[installInfo synchronize];
}
//任务的状态：接受：a； 完成：c
-(void)setTaskState:(questStatus)questStatus{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    if (questStatus == start) {
        [installInfo setObject:@"a" forKey:@"taskState"];
    }else if(questStatus == done){
        [installInfo setObject:@"c" forKey:@"taskState"];
    }
    else if(questStatus == fail)
    {
        [installInfo setObject:@"f" forKey:@"taskState"];
    }
    else{
        [installInfo setObject:@"unknown" forKey:@"taskState"];
    }
}
//任务的类型
-(void)setTaskType:(NSString *)taskType{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    if (0==[taskType length]) {
        [installInfo setObject:@"unknown" forKey:@"taskType"];
        
    }else{
        [installInfo setObject:taskType forKey:@"taskType"];
    }
    //[installInfo synchronize];
}





#pragma mark session——————————————————
/*//调用时机：   应用启动的时候调用。如果有session的缓存数据就发送。
 用户成功登录之后，记录一个session开始时间，在游戏HOME或关闭的时候记录一个session结束时间，
 同时计算出开始和结束时间之间的间隔的秒数，待下次startup时报送。*/


#pragma mark loggedin——————————————————
//发送login的数据
-(NSString *)ArrangeMessageLOGGEDIN{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    NSString * user_Id = [installInfo objectForKey:@"InstallappKeys"];
    NSString *accountid=[installInfo objectForKey:@"accountid"];
    NSString *level=[installInfo objectForKey:@"level"];
    NSString *gender=[installInfo objectForKey:@"gender"];
    NSString *birthday=[installInfo objectForKey:@"birthday"];
    NSString *serverid=[installInfo objectForKey:@"serverid"];
    if (0==[serverid length]) {
        serverid=@"unknown";
    }
    if (0==[gender length]) {
        gender=@"unknown";
    }
    if (0==[birthday length]) {
        birthday=@"unknown";
    }
    if (0==[level length]) {
        level=@"unknown";
    }
    
    NSDictionary *contextDic = [[NSMutableDictionary alloc] init];
    [contextDic setValue:[self GetUDId] forKey:@"deviceid"];
    [contextDic setValue:serverid forKey:@"serverid"];
    [contextDic setValue:[self GetChannel_Id] forKey:@"channelid"];
    [contextDic setValue:level forKey:@"level"];
    
    NSDictionary *root = [[NSMutableDictionary alloc] init];
    [root setValue:contextDic forKey:@"context"];
    [root setValue:user_Id forKey:@"appid"];
    [root setValue:accountid forKey:@"who"];
    [root setValue:@"loggedin" forKey:@"what"];
    [root setValue:[self currentTime] forKey:@"when"];
 
    RYSBJsonWriter *writer = [[RYSBJsonWriter alloc] init];
    NSLog(@"Start Create JSON!");
    NSString *body = [writer stringWithObject:root];
    NSLog(@"%@",body);
    return body;
    
}

#pragma mark heartbeat——————————————————
//在用户成功登录后（开发者调用loggedin方法后），每5分钟调用一次
//心跳的
-(NSString*)ArrangeMessageHeartBead{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    NSString* user_Id = [installInfo objectForKey:@"InstallappKeys"];
    NSString* accountid=[installInfo objectForKey:@"accountid"];
    NSString* serverid=[installInfo objectForKey:@"serverid"];
    NSString* levelStr = [installInfo objectForKey:@"level"];
    if ([serverid length]==0) {
        serverid=@"unknown";
    }
    if ([accountid length]==0) {
        accountid = @"unknown";
    }
    if ([serverid length]==0) {
        serverid = @"unknown";
    }
    NSDictionary *contextDic = [[NSMutableDictionary alloc] init];
    [contextDic setValue:[self GetUDId] forKey:@"deviceid"];
    [contextDic setValue:serverid forKey:@"serverid"];
    [contextDic setValue:[self GetChannel_Id] forKey:@"channelid"];
    [contextDic setValue:levelStr forKey:@"level"];
    
    NSDictionary *root = [[NSMutableDictionary alloc] init];
    [root setValue:contextDic forKey:@"context"];
    [root setValue:accountid forKey:@"who"];
    [root setValue:user_Id forKey:@"appid"];
    [root setValue:@"heartbeat" forKey:@"what"];
    [root setValue:[self currentTime] forKey:@"when"];
    
    RYSBJsonWriter *writer = [[RYSBJsonWriter alloc] init];
    NSLog(@"Start Create JSON!");
    NSString *body = [writer stringWithObject:root];
    NSLog(@"%@",body);
    
    return body;
}


//心跳的单例模式
-(void)heartBeatSendMessage:(BOOL)isBeadOpen{
    if (isBeadOpen == TRUE) {
        //[userdefault synchronize];
        //多次调用会启动多个心跳值，增加判断每次登陆只调用一次
        [[reyun sharedClick] heartBeadFun];
    }
}


//心跳模块
-(void)heartBeadFun{
    if (sendCatchMsg > 0) {
        [self sendURLConnectionAgain];
    }
    NSLog(@"====跳======================================");
    [[reyun sharedClick] SendBODYMessage:HEARTBEAD];
    sendCatchMsg++;
    NSUserDefaults* userdefault = [NSUserDefaults standardUserDefaults];
    NSInteger cycleHertTime = [[userdefault objectForKey:@"heartCountTime"] intValue];
    cycleHertTime =300;
    [self performSelector:@selector(heartBeadFun) withObject:nil afterDelay:cycleHertTime];
}



# define NLOG(name) NSLog(@"%@",name);
# define NLOGn(name) NSLog(name);



#pragma mark - 网络请求————————————
// 整理包体消息qc
-(void)SendBODYMessage:(CommandFunc)COMDFunc {
    
    NSString *body;
    NSString* urlStr;
    if (COMDFunc == INSTALL) {
        body = [self ArrangeDeviceInfo];
        urlStr = [NSString stringWithFormat:@"%@/receive/rest/install",checkversionurl];
        NLOGn(@"INSTALL__________");
    }else if(COMDFunc == STARTUP){
        body = [self ArrangeMessageSTARTUP];
        urlStr = [NSString stringWithFormat:@"%@/receive/rest/startup",checkversionurl];
        NLOGn(@"STARTUP___________");
    }else if(COMDFunc == REGED){
        body = [self ArrangeMessageReged];//  通过本身的方法 arrangmessagereged 获取 数据 赋值到body 中urlstrl  获取 报送地址
        urlStr = [NSString stringWithFormat:@"%@/receive/rest/register",checkversionurl];
        
        NLOGn(@"REGED————————————");
    }else if(COMDFunc == LOGGEDIN){
        body = [self ArrangeMessageLOGGEDIN];
        urlStr = [NSString stringWithFormat:@"%@/receive/rest/loggedin",checkversionurl];
        
        NLOGn(@"LOGGEDIN____________");
    }else if(COMDFunc == HEARTBEAD){
        body = [self ArrangeMessageHeartBead];
        urlStr = [NSString stringWithFormat:@"%@/receive/rest/heartbeat",checkversionurl];
        
        NLOGn(@"HEARTBEAD————————————");
    }else if(COMDFunc == PAYMENT){
        body = [self ArrangeMessagePayment];
        urlStr = [NSString stringWithFormat:@"%@/receive/rest/payment",checkversionurl];
        
        NLOGn(@"Payment___________");
    }else if(COMDFunc == ECONOMY){
        body = [self ArrangeMessageEconomy];
        urlStr = [NSString stringWithFormat:@"%@/receive/rest/economy",checkversionurl];
        
        NLOGn(@"ECONOMY————————————");
    }else if(COMDFunc == EVENT){
        body = [self ArrangeMessageEvent];
        urlStr = [NSString stringWithFormat:@"%@/receive/rest/event",checkversionurl];
        NLOGn(@"EVENT___________");
    }else if(COMDFunc == TASK){
        body = [self ArrangeMessageTask];
        urlStr = [NSString stringWithFormat:@"%@/receive/rest/quest",checkversionurl];
        NLOGn(@"TASK————————————");
    }
    else if(COMDFunc == GETTIME){
        urlStr = [NSString stringWithFormat:@"%@/receive/gettime",checkversionurl];
    }
    
    
    _groupId=[[RYDataBase sharedMyDataBase] getGroupID];
    _groupId++;
    //    NSLog(@"groupID:%d",_groupId);
    [[RYDataBase sharedMyDataBase] insertData:body groupID:_groupId];
    [self sendURLConnection:urlStr];
    //创建JSON
    
}
//发送网络 请求 获取数据库
-(void)sendURLConnection:(NSString*) newUrl{
    //    [self sendURLConnectionAgain];
    NSString *url = newUrl;
    NSArray *array=[[RYDataBase sharedMyDataBase] fillData];
    if ([array count]>0 ) {//&& isfirst
        NSString *str=[array lastObject];
        //NSLog(@"body________ %@",str);
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
        //新添加的
        NLOG(str);
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:[str dataUsingEncoding:NSUTF8StringEncoding]];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSString *len=[NSString stringWithFormat:@"%d",[str length]];
        [request setValue:len forHTTPHeaderField:@"Content-Length"];
        NSURLConnection *aUrlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:true];
        [aUrlConnection start];//开始连接网络
        //        [aUrlConnection release];//request不能release
    }
}
//没用到
-(NSDictionary*)StringToDic:(NSString * )tempStr{
    NSArray *array = [tempStr componentsSeparatedByString:@"&"];
    NSLog(@"animals:%@",array);
    NSMutableDictionary* dicTemp = [[NSMutableDictionary alloc] init];
    for (NSInteger i =0 ; i<[array count]; i++) {
        NSString* tempStr =[array objectAtIndex:i];
        NSArray* arraySepTemp = [tempStr componentsSeparatedByString:@"="];
        NSString* prevalue =[arraySepTemp objectAtIndex:0];
        NSString* postValue = [arraySepTemp objectAtIndex:1];
        if ([prevalue length]!=0) {
            [dicTemp setObject:postValue forKey:prevalue];
        }
    }
    return [dicTemp autorelease];
}

-(void)sendURLConnectionAgain{
    NSString *url = [NSString stringWithFormat:@"%@/receive/batch",checkversionurl];
    ;
    NSArray *array=[[RYDataBase sharedMyDataBase] fillData];//从数据库取出来数据
    NSMutableDictionary* finalDic = [[NSMutableDictionary alloc] init];
    NSMutableArray * afterArr = [[NSMutableArray alloc] init];
    NSString* dataStr = [NSString stringWithFormat:@"{\"appid\":\"%@\",\"data\":[",[self GetUDId]];
    
    if ([array count]>0 ) {//判断 失败 的数据 是否为 0
        for (int i=0; i<[array count]; i++) {
            dataStr = [dataStr stringByAppendingString:[array objectAtIndex:i]];
            
            if ((i+1)!=[array count]) {
                dataStr = [dataStr stringByAppendingString:@","];
            }
            
            if (i>=100) {
                break;
            }//每次发送一百条
            
            
        }/**
          拼接 数据 以 ， 隔开， 准备发送数据
          
          */
        
        dataStr = [dataStr stringByAppendingString:@"]"];
        dataStr = [dataStr stringByAppendingString:@"}"];
        //     NSString *str = [writer stringWithObject:dataStr];//dic就是你将要转换成字典，而returnString就是齐刷刷的json数据了
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
        //新添加的
        
        NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
        NSString* user_Id = [installInfo objectForKey:@"InstallappKeys"];
        
        //        NSString* postData = [NSString stringWithFormat:@"appid=%@&data=%@",user_Id,str];
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:[dataStr dataUsingEncoding:NSUTF8StringEncoding]];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSString *len=[NSString stringWithFormat:@"%d",[dataStr length]];
        [request setValue:len forHTTPHeaderField:@"Content-Length"];
        NSURLConnection *aUrlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:true];
        [aUrlConnection start];//开始连接网络
        [aUrlConnection release];//request不能release
        
        arrayCount = [array count];
    }
    [afterArr release];
    
    
    //   [self performSelector:@selector(sendURLConnectionAgain) withObject:nil afterDelay:30];
}

//获取 服务器时间
-(void)getServersTime{
    NSString *url = [NSString stringWithFormat:@"%@/receive/gettime",checkversionurl];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    //新添加的
    [request setHTTPMethod:@"POST"];
    NSString* str = nil;
    [request setHTTPBody:[str dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSString *len=[NSString stringWithFormat:@"%d",[str length]];
    [request setValue:len forHTTPHeaderField:@"Content-Length"];
    NSURLConnection *aUrlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:true];
    [aUrlConnection start];//开始连接网络
}


//第一次进入 获取时间  （部分）
-(void)downLoadFinish:(NSMutableData*)data
{
    NSUserDefaults* installInfo = [NSUserDefaults  standardUserDefaults];
    NSMutableDictionary *rootDict=[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    //NSLog(@"rootDict%@",rootDict);
    
    NSString *serversTime=[rootDict objectForKey:@"ts"];
    //NSLog(@"serversTime:%@",serversTime);
     NSTimeInterval nowtime = [[NSDate date] timeIntervalSince1970];
    long long dataTime = [[NSNumber numberWithDouble:nowtime] longLongValue]; // 将double转为long long型
    //NSLog(@"currentTime:%lld",dataTime);
    if ([serversTime longLongValue]>0) {
        long long marginTime = [serversTime longLongValue]/1000 - dataTime;
        [installInfo setObject:[NSNumber numberWithLongLong:marginTime] forKey:@"marginTime"];
        [installInfo synchronize];
        _marginTime=[[installInfo objectForKey:@"marginTime"] longLongValue];
        //NSLog(@"_marginTime%lld",_marginTime);
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response  {
    if (arrayCount>0) {//补发机制
        for (int i = 0; i<arrayCount; i++) {
            if (i>=100) {
                break;
            }
            
            //TODO 这块逻辑没搞明白
            NSInteger changeID = [[RYDataBase sharedMyDataBase] getID];
            [[RYDataBase sharedMyDataBase] changeSaveMark:0 groupid:changeID];//修改数据库 数据状态
            
            [[RYDataBase sharedMyDataBase] removeData];//根据数据库状态 删除
        }
        arrayCount = 0;
        
        
    }
    else{
        //如果没有 可发送的 错误数据 的话
        static long long i=0;
        NSLog(@"接收完响应:%lld %@",i,response);
        _haveURL=YES;//当网络请求成功时开启循环调用网络请求
        //发送成功后将currentSendDate对应body值设置为空
        
        NSInteger changeId=[[RYDataBase sharedMyDataBase] getGroupID];
        
        [[RYDataBase sharedMyDataBase] changeSaveMark:0 groupid:changeId];
        [[RYDataBase sharedMyDataBase] removeData];
        //NSLog(@"changeID!!!!!!!!!!!!!!!!%d",_ch   angeId);
        [_receivedData setLength:0];
        //TODO

            [[reyun sharedClick] sendURLConnectionAgainTransition];
        NSLog(@"我在走");

        
        

    }
}


-(void)sendURLConnectionAgainTransition{
    [self performSelector:@selector(sendURLConnectionAgain) withObject:nil afterDelay:30];
}


//接收数据完成
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data  {
    //NSLog(@"data%@",data);
    [_receivedData appendData:data];
    NSDictionary* dic = (NSDictionary*)data;
   
    NSString *mmmmmmm = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
   
    NSError* error = nil;
    NSDictionary* photo = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];

    
    NSMutableArray *allKey = [[NSMutableArray alloc]init];
    id object;
    NSEnumerator * enumer = [photo keyEnumerator];
    while (object=[enumer nextObject]) {
        [allKey addObject:object];
    }
    for(NSString * key in allKey)
    {
        if ([key isEqualToString:@"ts"]) {
            NSMutableData* dataTemp = [[NSMutableData alloc] initWithData:data];
            [self downLoadFinish:dataTemp];
        }
    }
    
    NSLog(@"接收完数据:");
   
}



//链接错误
-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error  {
    static int i=1;
    NSLog(@"数据接收错误:%d  %@",i++,error);
    _haveURL=NO;
}
//链接结束
- (void)connectionDidFinishLoading:(NSURLConnection *)connection  {
    NSLog(@"连接完成:%@",connection);

    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    if ([connection isEqual:_ServerConnection]) {
        // NSLog(@"_receivedData%@",_ServerConnection);
        [self downLoadFinish:_receivedData];
    }
}

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection{
    return NO;
}


//下面两段是重点，要服务器端单项HTTPS 验证，iOS 客户端忽略证书验证。

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    
    NSLog(@"didReceiveAuthenticationChallenge %@ %zd", [[challenge protectionSpace] authenticationMethod], (ssize_t) [challenge previousFailureCount]);
    
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]){
        
        [[challenge sender]  useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
        
        [[challenge sender]  continueWithoutCredentialForAuthenticationChallenge: challenge];
        
    }
}



- (NSString *) platform{
    
    size_t size;
    
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    
    char *machine = malloc(size);
    
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    
    NSString *platform = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
    
    free(machine);
    
    return platform;
}

- (NSString *) platformString{
    
    NSString *platform = [self platform];
    return platform;
}


//目前没用

+ (void)startPageViewlog:(NSString *)pageName{
    NSUserDefaults *reportInfo = [NSUserDefaults standardUserDefaults];
    NSDate* date = [NSDate date];
    [[NSDate date] timeIntervalSince1970];
    [reportInfo setObject:date forKey:pageName];
}

//目前没用
+ (void)endPageViewlog:(NSString *)pageName{
    NSUserDefaults* reportInfo = [NSUserDefaults standardUserDefaults];
    NSDate* date =  [reportInfo objectForKey:pageName];
    if (date==nil) {
        return;
    }
    NSDate* datenow = [NSDate date];
    [[NSDate date] timeIntervalSince1970];
    NSInteger infoRepo= [datenow timeIntervalSinceDate:date];
    NSString* currentTime = [NSString stringWithFormat:@"%@:%d",pageName,infoRepo];
    [reportInfo setObject:currentTime forKey:@"sessionForTimeRequest"];
}

//游戏开始时间， 目前没有使用
- (void)startGameTime{
    NSUserDefaults *reportInfo = [NSUserDefaults standardUserDefaults];
    
    NSTimeInterval nowtime = [[NSDate date] timeIntervalSince1970];
    long long dataTime = [[NSNumber numberWithDouble:nowtime] longLongValue]; // 将double转为long long型
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:(dataTime + _marginTime)];
    NSString *startmachine = [formatter stringFromDate:date];
    [formatter release];
    
    [reportInfo setObject:startmachine forKey:@"startmachine"];//存储开始时间
    
}

//游戏结束时间， 目前没有使用
+ (void)endGameTime{
    NSUserDefaults* reportInfo = [NSUserDefaults standardUserDefaults];
    NSString * startmachine =  [reportInfo objectForKey:@"startmachine"];
    if (startmachine == nil) {
        return;
    }
    NSTimeInterval nowtime = [[NSDate date] timeIntervalSince1970];
    long long dataTime = [[NSNumber numberWithDouble:nowtime] longLongValue]; // 将double转为long long型
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:(dataTime + _marginTime)];
    NSString *endstartmachine = [formatter stringFromDate:date];
    [reportInfo setObject:endstartmachine forKey:@"endstartmachine"];//存储结束时间
    
    NSDate *dateStart=[formatter dateFromString:startmachine];
    NSDate *dateEnd=[formatter dateFromString:endstartmachine];
    long long time=[dateEnd timeIntervalSinceDate:dateStart];
    [formatter release];
    
    [reportInfo setObject:[NSString stringWithFormat:@"%lld",time] forKey:@"sessionForTimeRequest"];//存储持续时间
    [reportInfo synchronize];
    //NSLog(@"持续时间:%@",[reportInfo objectForKey:@"sessionForTimeRequest"]);
    
}

//InstallappKey
//转换时间
-(NSString*)secondConverter:(NSInteger)secondstr {
    int second = 0;
    second = secondstr;
    int hh = 0;
    int mm = 0;
    int ss = 0;
    int temp = second % 3600;
    if (second > 3600) {
        hh = second / 3600;
        if (temp != 0) {
            if (temp > 60) {
                mm = temp / 60;
                if (temp % 60 != 0) {
                    ss = temp % 60;
                }
            } else {
                ss = temp;
            }
        }
    } else {
        mm = second / 60;
        if (second % 60 != 0) {
            ss = second % 60;
        }
    }
    NSString* timetype = [NSString stringWithFormat:@"%d:%d:%d",hh,mm,ss];
    return timetype;
}

//判断 手机运营商
-(NSString* )getCellYunYingShangName {
    CTTelephonyNetworkInfo *info = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = info.subscriberCellularProvider;
    [info release];
    NSString * str=carrier.carrierName;
    if (str.length>0) {
        return str;
    }else{
        return @"unknown";
    }
    //return carrier.carrierName;
    
}

//判断网络
-(NSString*)currentStatus{
    BOOL twoGisAvailable = [RYReachabilitysdk isNetWorkVia2G];
    BOOL threeGisAvailable = [RYReachabilitysdk isNetWorkVia3G];
    BOOL wifiIsAviable = [RYReachabilitysdk isNetWorkViaWiFi];
    NSString* currentNETStatus;
    if (wifiIsAviable) {
        currentNETStatus = @"WIFI";
    }
    else if(threeGisAvailable){
        currentNETStatus = @"3G";
    }
    else if(twoGisAvailable){
        currentNETStatus = @"2G";
    }
    else{
        currentNETStatus = @"NO CONNECT";
    }
    return currentNETStatus;
}

// 以隔离时间发送数据。
-(void)counterTotalSend{
    NSUserDefaults* userdefault = [NSUserDefaults standardUserDefaults];
    NSMutableArray* CounterDate = [userdefault objectForKey:@"counterArray"];
    NSInteger reportCount = [[userdefault objectForKey:@"counterNum"] intValue];
    if (reportCount<=0||reportCount>30) {
        reportCount = 30;
    }
    NSString* HttpBody = [self restoreStrFromArray:CounterDate];
    
    if ([CounterDate count]>=reportCount) {
        NSString *url = checkversionurl;
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:[HttpBody dataUsingEncoding:NSUTF8StringEncoding]];
        NSURLConnection *aUrlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:true];
        [aUrlConnection start];//开始连接网络
        [aUrlConnection release];
        [userdefault setObject:nil forKey:@"counterArray"];
    }
}

// httpbody  可能是拼接 json 串
-(NSString*)restoreStrFromArray:(NSMutableArray*)restoreArray{
    NSString* bodyStr = @"data={counters:[";
    for (int i=0; i<[restoreArray count]; i++) {
        bodyStr = [bodyStr stringByAppendingFormat:@"%@",@"{"];
        bodyStr = [bodyStr stringByAppendingFormat:@"%@",[restoreArray objectAtIndex:i]];
        if ([restoreArray count] != i+1) {
            bodyStr = [bodyStr stringByAppendingFormat:@"%@",@"},"];
        }
        [bodyStr stringByAppendingFormat:@"%@",@"}"];
    }
    bodyStr = [bodyStr stringByAppendingFormat:@"%@",@"}]}&dataType=counters"];
    return bodyStr;
}


//获取 区域编码
-(NSString*) gotlocal{
    NSLocale *currentUsersLocale = [NSLocale currentLocale];
    NSString* localIdentifier = [currentUsersLocale localeIdentifier];
    NSLog(@"Current Locale: %@", localIdentifier);
    NSString* region = nil;
    //ISO 3166 国家编码http://zh.wikipedia.org/zh-cn/ISO_3166-1
    // 获取所有已知合法的国家代码数组列表
    NSArray* codes = [NSLocale ISOCountryCodes];
    
    BOOL findCountry = NO;
    NSRange range = [localIdentifier  rangeOfString:@"_"];
    NSString* contry  = nil;
    if(range.location !=NSNotFound)
    {
        contry = [localIdentifier substringFromIndex:(range.location+range.length)];
        NSLog(@"contry:%@",contry);
        
        
        NSUInteger idx = NSUIntegerMax;
        idx = [codes indexOfObject:contry];
        if(idx < [codes count])
        {
            findCountry = YES;
        }
    }
    if(findCountry)
    {
        NSLog(@"contry is %@",contry);
        if([[contry uppercaseString] isEqualToString:@"HK"]||
           [[contry uppercaseString] isEqualToString:@"MO"]||
           [[contry uppercaseString] isEqualToString:@"TW"])
        {
            contry = @"CN";
        }
        region = contry;
    }
    else
    {
        region = @"未知";
    }
    return region;
}

//获取设备id
+(NSString*)getDeviceId{
    NSString *idfa = Nil;
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 6.0f)
    {
        NSLog(@"大于6级");
        idfa = [RYSSKeychain passwordForService:@"serviceID" account:@"SSToolkitTestAccount"];
    }
    else
    {
        NSLog(@"小于6级");
        idfa = [RYOpenUDID value];
    }
    
    if ([idfa length]==0) {
        NSString *writeIDFAToKeychain=[[[ASIdentifierManager sharedManager]advertisingIdentifier]UUIDString];
        [RYSSKeychain setPassword:writeIDFAToKeychain forService:@"serviceID" account:@"SSToolkitTestAccount"];
        idfa = [RYSSKeychain passwordForService:@"serviceID" account:@"SSToolkitTestAccount"];
    }
    return idfa;
}


//获得当前时间
-(NSString*)currentTime{
    
    NSTimeInterval nowtime = [[NSDate date] timeIntervalSince1970];
    long long dataTime = [[NSNumber numberWithDouble:nowtime] longLongValue]; // 将double转为long long型
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:(dataTime + _marginTime)];
    NSString *currentTime = [formatter stringFromDate:date];
    //NSLog(@"___________________currentTime:%@",currentTime);
    [formatter release];
    return currentTime;
}
-(NSString *)getIdFv
{
    NSString *idfv = Nil;
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 6.0f)
    {
        NSLog(@"大于6级");
        idfv = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    }
    else
    {
        NSLog(@"小于6级");
        idfv = [RYOpenUDID value];
    }
    
    if ([idfv length]==0) {
        NSString *writeIDFAToKeychain=[[[ASIdentifierManager sharedManager]advertisingIdentifier]UUIDString];
        [RYSSKeychain setPassword:writeIDFAToKeychain forService:@"serviceID" account:@"SSToolkitTestAccount"];
        idfv = [RYSSKeychain passwordForService:@"serviceID" account:@"SSToolkitTestAccount"];
    }
    return idfv;
    
}
-(NSString *)getIdFa
{
    NSString *idfa = Nil;
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 6.0f)
    {
        NSLog(@"大于6级");
        idfa = [[[ASIdentifierManager sharedManager]advertisingIdentifier]UUIDString];
    }
    else
    {
        NSLog(@"小于6级");
        idfa = [RYOpenUDID value];
    }
    
    if ([idfa length]==0) {
        NSString *writeIDFAToKeychain=[[[ASIdentifierManager sharedManager]advertisingIdentifier]UUIDString];
        [RYSSKeychain setPassword:writeIDFAToKeychain forService:@"serviceID" account:@"SSToolkitTestAccount"];
        idfa = [RYSSKeychain passwordForService:@"serviceID" account:@"SSToolkitTestAccount"];
    }
    return idfa;
    
    
}
//UDId  获取设备标示符
-(NSString*)GetUDId {
    NSString *udid = Nil;
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 6.0f)
    {
        NSLog(@"大于6级");
        udid = [RYSSKeychain passwordForService:@"serviceID" account:@"SSToolkitTestAccount"];
    }
    else
    {
        NSLog(@"小于6级");
        udid = [RYOpenUDID value];
    }
    
    if ([udid length]==0) {
        NSString *writeIDFAToKeychain=[[[ASIdentifierManager sharedManager]advertisingIdentifier]UUIDString];
        [RYSSKeychain setPassword:writeIDFAToKeychain forService:@"serviceID" account:@"SSToolkitTestAccount"];
        udid = [RYSSKeychain passwordForService:@"serviceID" account:@"SSToolkitTestAccount"];
    }
    return udid;
    
}
//设备分辨率
-(NSString*)GetDeviceDpi{
    CGRect rect = [[UIScreen mainScreen] bounds];
    CGSize size = rect.size;
    NSString* dpiStr = [NSString stringWithFormat:@"%d*%d",(int)size.height,(int)size.width];
    //NSLog(@"size:%@",dpiStr);
    return dpiStr;
}
//系统名称 版本
-(NSString*)systemVersion{
    NSString* systemVersion = [NSString stringWithFormat:@"%@ %@",[UIDevice currentDevice].systemName,[UIDevice currentDevice].systemVersion];
    //NSLog(@"os:%@",systemVersion);
    //NSLog(@"%@",[self currentResolution]);
    return systemVersion;
}
//获取设备型号
-(NSString*)deviceType{
    NSString* deviceType =[UIDevice currentDevice].model;
    //NSLog(@"deviceType:%@",deviceType);
    return deviceType;
}


//设置 extra 参数
-(NSString*)setextraInfo:(NSArray* )infoarray{
    NSString* strForExtra = @"";
    for (int infoCount = 0; infoCount <[infoarray count]; infoCount++) {
        strForExtra = [strForExtra stringByAppendingFormat:@"%d:",infoCount+1];
        strForExtra = [strForExtra stringByAppendingString:[infoarray objectAtIndex:infoCount]];
        if (infoCount !=[infoarray count]-1) {
            strForExtra = [strForExtra stringByAppendingString:@","];
        }
    }
    //    strForExtra = [strForExtra stringByAppendingFormat:@"}"];
    return strForExtra;
}



//获得time zone 时区
-(NSString*)GetTimeZone{
    
    NSTimeZone *zone = [NSTimeZone defaultTimeZone];//获得当前应用程序默认的时区
    NSString* currentZone = [NSString stringWithFormat:@"%@",zone];
    NSArray * array = [currentZone componentsSeparatedByString:@" "];
    // NSLog(@"tz_____%@____%@",currentZone, array);
    if ([[array objectAtIndex:1] length] >=5) {
        NSRange range=NSMakeRange(4,[[array objectAtIndex:1] length]-5);//
        NSString *str=[[array objectAtIndex:1] substringWithRange:range];
        //NSLog(@"str:%@",str);
        return str;
    }else{
        if ([[array objectAtIndex:2] length]>=3) {
            NSRange range=NSMakeRange(1,[[array objectAtIndex:2] length]-3);//
            NSString *str=[[array objectAtIndex:2] substringWithRange:range];
            //NSLog(@"str:%@",str);
            return str;
        }else{
            return @"unknown";
        }
    }
}


//==============================================数据层//

#pragma mark  instal---------------
// 安装信息的布置//安装后第一次启动调用
-(NSString*)ArrangeDeviceInfo {
    
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    NSString* user_Id = [installInfo objectForKey:@"InstallappKeys"];
    NSString *serverid=[installInfo objectForKey:@"serverid"];
    
    if ([serverid length]==0) {
        serverid = @"unknown";
    }
    NSDictionary *contextDic = [[NSMutableDictionary alloc] init];
    [contextDic setValue:[self GetUDId] forKey:@"deviceid"];
    [contextDic setValue:[self getIdFa] forKey:@"idfa"];
    [contextDic setValue:[self getIdFv] forKey:@"idfv"];
    [contextDic setValue:serverid forKey:@"serverid"];
    [contextDic setValue:[self GetChannel_Id] forKey:@"channelid"];
    
    NSDictionary *root = [[NSMutableDictionary alloc] init];
    [root setValue:contextDic forKey:@"context"];
    [root setValue:user_Id forKey:@"appid"];
    [root setValue:@"install" forKey:@"what"];
    [root setValue:[self currentTime] forKey:@"when"];
    
    RYSBJsonWriter *writer = [[RYSBJsonWriter alloc] init];
    NSLog(@"Start Create JSON!");
    NSString *body = [writer stringWithObject:root];
    NSLog(@"%@",body);
    return body;
}
#pragma mark  reged---------------
// 用户成功注册返回后调用
-(NSString*)ArrangeMessageReged {
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    NSString* user_Id = [installInfo objectForKey:@"InstallappKeys"];
    NSString *accountid=[installInfo objectForKey:@"accountid"];
    NSString *serverid=[installInfo objectForKey:@"serverid"];
    NSString *gender=[installInfo objectForKey:@"gender"];
    NSString *birthday=[installInfo objectForKey:@"birthday"];
    NSString *accountType=[installInfo objectForKey:@"accountType"];
    if (0==[serverid length]) {
        serverid=@"unknown";
    }
    if (0==[gender length]) {
        gender=@"unknown";
    }
    if (0==[birthday length]) {
        birthday=@"unknown";
    }
    if (0==[accountType length]) {
        accountType=@"unknown";
    }
    
    NSDictionary *contextDic = [[NSMutableDictionary alloc] init];
    [contextDic setValue:[self GetUDId] forKey:@"deviceid"];
    [contextDic setValue:[self getIdFa] forKey:@"idfa"];
    [contextDic setValue:[self getIdFv] forKey:@"idfv"];
    [contextDic setValue:accountType forKey:@"accounttype"];
    [contextDic setValue:gender forKey:@"gender"];
    [contextDic setValue:birthday forKey:@"age"];
    [contextDic setValue:serverid forKey:@"serverid"];
    [contextDic setValue:[self GetChannel_Id] forKey:@"channelid"];
    
    NSDictionary *root = [[NSMutableDictionary alloc] init];
    [root setValue:contextDic forKey:@"context"];
    [root setValue:user_Id forKey:@"appid"];
    [root setValue:accountid forKey:@"who"];
    [root setValue:@"register" forKey:@"what"];
    [root setValue:[self currentTime] forKey:@"when"];
    
    RYSBJsonWriter *writer = [[RYSBJsonWriter alloc] init];
    NSLog(@"Start Create JSON!");
    NSString *body = [writer stringWithObject:root];
    NSLog(@"%@",body);
    return body;
}
#pragma mark  STARTUP---------------
// DAU信息的布置   每次启动时调用；包括第一次启动。
- (NSString*)ArrangeMessageSTARTUP{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    NSString* user_Id = [installInfo objectForKey:@"InstallappKeys"];
    NSString* serverid = [installInfo objectForKey:@"serverid"];
    if ([serverid length]==0) {
        serverid = @"unknown";
    }
    NSDictionary *contextDic = [[NSMutableDictionary alloc] init];
    [contextDic setValue:[self GetUDId] forKey:@"deviceid"];
    [contextDic setValue:[self getIdFa] forKey:@"idfa"];
    [contextDic setValue:[self getIdFv] forKey:@"idfv"];
    [contextDic setValue:serverid forKey:@"serverid"];
    [contextDic setValue:[self GetChannel_Id] forKey:@"channelid"];
    [contextDic setValue:[self GetTimeZone] forKey:@"tz"];
    [contextDic setValue:[self deviceType] forKey:@"devicetype"];
    [contextDic setValue:[self getCellYunYingShangName] forKey:@"op"];
    [contextDic setValue:[self currentStatus] forKey:@"network"];
    [contextDic setValue:[self systemVersion] forKey:@"os"];
    [contextDic setValue:[self GetDeviceDpi] forKey:@"resolution"];
    
    NSDictionary *root = [[NSMutableDictionary alloc] init];
    [root setValue:contextDic forKey:@"context"];
    [root setValue:user_Id forKey:@"appid"];
    [root setValue:@"startup" forKey:@"what"];
    [root setValue:[self currentTime] forKey:@"when"];
    
    RYSBJsonWriter *writer = [[RYSBJsonWriter alloc] init];
    NSLog(@"Start Create JSON!");
    NSString *body = [writer stringWithObject:root];
    NSLog(@"%@",body);
    
    return body;
}

#pragma mark event——————————————————
//事件发生之后调用
-(NSString *)ArrangeMessageEvent{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    NSString* user_Id = [installInfo objectForKey:@"InstallappKeys"];
    NSString* accountid=[installInfo objectForKey:@"accountid"];
    NSString *location=[installInfo objectForKey:@"location"];
    NSString *eventName=[installInfo objectForKey:@"eventName"];
    NSString* serverid=[installInfo objectForKey:@"serverid"];
    NSDictionary *extra=[installInfo objectForKey:@"extra"];//设置为字典
    if (0==[location length]) {
        location=@"unknown";
    }
    if (0==[serverid length]) {
        serverid=@"unknown";
    }
    NSDictionary *contextDic = [[NSMutableDictionary alloc] init];
    NSMutableString *MutableString=[[NSMutableString alloc]init];
    NSMutableArray *allKey = [[NSMutableArray alloc]init];
    id object;
    NSEnumerator * enumer = [extra keyEnumerator];
    while (object=[enumer nextObject]) {
        [allKey addObject:object];
    }
    for(NSString * key in allKey)
    {
        [contextDic setValue:[extra objectForKey:key] forKey:key];
    }
    [contextDic setValue:[self GetUDId] forKey:@"deviceid"];
    [contextDic setValue:[self getIdFa] forKey:@"idfa"];
    [contextDic setValue:[self getIdFv] forKey:@"idfv"];
    [contextDic setValue:serverid forKey:@"serverid"];
    [contextDic setValue:[self GetChannel_Id] forKey:@"channelid"];
    
    NSDictionary *root = [[NSMutableDictionary alloc] init];
    [root setValue:contextDic forKey:@"context"];
    [root setValue:user_Id forKey:@"appid"];
    [root setValue:accountid forKey:@"who"];
    [root setValue:eventName forKey:@"what"];
    [root setValue:[self currentTime] forKey:@"when"];
    
    
    RYSBJsonWriter *writer = [[RYSBJsonWriter alloc] init];
    NSLog(@"Start Create JSON!");
    NSString *body = [writer stringWithObject:root];
    NSLog(@"%@",body);
    
    
    //NSLog(@"MutableString ________%@",MutableString);
    //    NSString* body = [NSString stringWithFormat:@"appid=%@&who=%@&when=%@&where=%@&what=%@&context=serverid\001%@%@\002channelid\001%@",user_Id,accountid,[self currentTime],eventName,eventName,serverid,MutableString,[self GetChannel_Id]];
    //    [allKey release];
    //    [MutableString release];
    return body;
    
}
#pragma mark payment——————————————————
//用户充值之后调用
-(NSString *)ArrangeMessagePayment{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    NSString * user_Id = [installInfo objectForKey:@"InstallappKeys"];
    NSString *accountid=[installInfo objectForKey:@"accountid"];
    NSString *serverid=[installInfo objectForKey:@"serverid"];
    NSString * level=[installInfo objectForKey:@"level"];
    NSString * gender=[installInfo objectForKey:@"gender"];
    NSString *birthday=[installInfo objectForKey:@"birthday"];
    //    NSString *amount=[installInfo objectForKey:@"amount"];//用户成功充值，充值的金额
    NSString *iapAmountStr = [installInfo objectForKey:@"iapAmount"];
    NSString *transactionIdStr = [installInfo objectForKey:@"transactionId"];
    NSString *paymentTypestr = [installInfo objectForKey:@"paymentType"];
    NSString *currenctyTypestr = [installInfo objectForKey:@"currenctyType"];
    NSString *iapNameStr = [installInfo objectForKey:@"iapName"];
    NSString *currencyAmountStr = [installInfo objectForKey:@"currencyAmount"];
    NSString *virtualCoinAmountStr = [installInfo objectForKey:@"virtualCoinAmount"];
    
    if (0==[birthday length]) {
        birthday=@"unknown";
    }
    if (0==[gender length]) {
        gender=@"unknown";
    }
    if (0==[level length]) {
        level=@"-1";
    }
    if (0==[serverid length]) {
        serverid=@"unknown";
    }
    
    NSDictionary *contextDic = [[NSMutableDictionary alloc] init];
    [contextDic setValue:[self GetUDId] forKey:@"deviceid"];
    [contextDic setValue:[self getIdFa] forKey:@"idfa"];
    [contextDic setValue:[self getIdFv] forKey:@"idfv"];
    [contextDic setValue:transactionIdStr forKey:@"transactionid"];
    [contextDic setValue:paymentTypestr forKey:@"paymenttype"];
    [contextDic setValue:currenctyTypestr forKey:@"currencytype"];
    [contextDic setValue:currencyAmountStr forKey:@"currencyamount"];
    [contextDic setValue:virtualCoinAmountStr forKey:@"virtualcoinamount"];
    [contextDic setValue:iapNameStr forKey:@"iapname"];
    [contextDic setValue:iapAmountStr forKey:@"iapamount"];
    [contextDic setValue:serverid forKey:@"serverid"];
    [contextDic setValue:[self GetChannel_Id] forKey:@"channelid"];
    [contextDic setValue:level forKey:@"level"];
    
    NSDictionary *root = [[NSMutableDictionary alloc] init];
    [root setValue:contextDic forKey:@"context"];
    [root setValue:accountid forKey:@"who"];
    [root setValue:user_Id forKey:@"appid"];
    [root setValue:@"payment" forKey:@"what"];
    [root setValue:[self currentTime] forKey:@"when"];
    
    RYSBJsonWriter *writer = [[RYSBJsonWriter alloc] init];
    NSLog(@"Start Create JSON!");
    NSString *body = [writer stringWithObject:root];
    NSLog(@"%@",body);
    
    return body;
    
}
#pragma mark economy——————————————————
//虚拟交易发生之后调用
-(NSString *)ArrangeMessageEconomy{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    NSString* user_Id = [installInfo objectForKey:@"InstallappKeys"];
    NSString *accountid=[installInfo objectForKey:@"accountid"];
    NSString *serverid=[installInfo objectForKey:@"serverid"];
    NSString * level=[installInfo objectForKey:@"level"];
    NSString *num=[installInfo objectForKey:@"num"];
    NSString * name=[installInfo objectForKey:@"name"];
    float totalPrice=[[installInfo objectForKey:@"totalPrice"] floatValue];
    NSString *type=[installInfo objectForKey:@"type"];
    
    if (0==[num length]) {
        num=@"unknown";
    }
    if (0==[name length]) {
        name=@"unknown";
    }
    if (0==[type length]) {
        type=@"unknown";
    }
    if (0==[level length]) {
        level=@"unknown";
    }
    if (0==[serverid length]) {
        serverid=@"unknown";
    }
    if (0==[accountid length]) {
        accountid = @"unknown";
    }
    
    NSDictionary *contextDic = [[NSMutableDictionary alloc] init];
    [contextDic setValue:[self GetUDId] forKey:@"deviceid"];
    [contextDic setValue:[self getIdFa] forKey:@"idfa"];
    [contextDic setValue:[self getIdFv] forKey:@"idfv"];
    [contextDic setValue:name forKey:@"itemname"];
    [contextDic setValue:num forKey:@"itemamount"];
    [contextDic setValue:[NSString stringWithFormat:@"%0.2f",totalPrice] forKey:@"itemtotalprice"];
    [contextDic setValue:serverid forKey:@"serverid"];
    [contextDic setValue:[self GetChannel_Id] forKey:@"channelid"];
    [contextDic setValue:level forKey:@"level"];
    
    NSDictionary *root = [[NSMutableDictionary alloc] init];
    [root setValue:contextDic forKey:@"context"];
    [root setValue:user_Id forKey:@"appid"];
    [root setValue:accountid forKey:@"who"];
    [root setValue:@"economy" forKey:@"what"];
    [root setValue:[self currentTime] forKey:@"when"];
    
    RYSBJsonWriter *writer = [[RYSBJsonWriter alloc] init];
    NSLog(@"Start Create JSON!");
    NSString *body = [writer stringWithObject:root];
    NSLog(@"%@",body);
    return body;
}
#pragma mark task——————————————————
//用户接受任务/用户完成任务之后
-(NSString *)ArrangeMessageTask{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    NSString* user_Id = [installInfo objectForKey:@"InstallappKeys"];
    NSString *accountid=[installInfo objectForKey:@"accountid"];
    NSString *serverid=[installInfo objectForKey:@"serverid"];
    NSString * level=[installInfo objectForKey:@"level"];
    NSString * taskId=[installInfo objectForKey:@"taskId"];
    NSString * taskState=[installInfo objectForKey:@"taskState"];
    NSString * taskType=[installInfo objectForKey:@"taskType"];
    
    if (0==[taskId length]) {
        taskId=@"unknown";
    }
    if (0==[taskType length]) {
        taskType=@"unknown";
    }
    if (0==[level length]) {
        level=@"unknown";
    }
    if (0==[serverid length]) {
        serverid=@"unknown";
    }
    
    NSDictionary *contextDic = [[NSMutableDictionary alloc] init];
    [contextDic setValue:[self GetUDId] forKey:@"deviceid"];
    [contextDic setValue:[self getIdFa] forKey:@"idfa"];
    [contextDic setValue:[self getIdFv] forKey:@"idfv"];
    [contextDic setValue:taskId forKey:@"questId"];
    [contextDic setValue:taskState forKey:@"queststatus"];
    [contextDic setValue:taskType forKey:@"questtype"];
    [contextDic setValue:serverid forKey:@"serverid"];
    [contextDic setValue:[self GetChannel_Id] forKey:@"channelid"];
    [contextDic setValue:level forKey:@"level"];
    
    NSDictionary *root = [[NSMutableDictionary alloc] init];
    [root setValue:contextDic forKey:@"context"];
    [root setValue:user_Id forKey:@"appid"];
    [root setValue:accountid forKey:@"who"];
    [root setValue:@"quest" forKey:@"what"];
    [root setValue:[self currentTime] forKey:@"when"];
    
    
    RYSBJsonWriter *writer = [[RYSBJsonWriter alloc] init];
    NSLog(@"Start Create JSON!");
    NSString *body = [writer stringWithObject:root];
    NSLog(@"%@",body);
    
    return body;
}





@end

/*
#import "reyun.h"

@implementation reyun

@end
*/