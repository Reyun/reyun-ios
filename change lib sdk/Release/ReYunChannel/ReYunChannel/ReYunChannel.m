//
//  ReYunChannel.m
//  ReYunChannel
//
//  Created by yun on 14/12/17.
//  Copyright (c) 2014年 reyun. All rights reserved.
//

#import "ReYunChannel.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <AdSupport/ASIdentifierManager.h>//广告标识符
#import "OpenUDIDSDK.h"
#import "RYReachabilitysdk.h"//判断网络
#import <ifaddrs.h>
#include <arpa/inet.h>
#import "ChannelDataBase.h"
#import "RYSSKeychain.h"
#import "RYSBJSON.h"
#define MAXADDRS 255
#define AppName [[[NSBundle mainBundle] infoDictionary] objectForKey:@"Bundle name"]
#define APP_VERSION [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey]
#define checkversionurl @"http://log.reyun.com"         //热云网服务器新
//#define checkversionurl @"http://192.168.2.241:8180"
ReYunChannel* reYunChannelaClick = NULL;
NSInteger _groupId;
NSMutableData *_receivedData;
long long  _reYunChannelmarginTime=0;
static BOOL _haveURL=NO;
NSURLConnection *_ServerConnection;
NSInteger arrayCount;
NSInteger sendCatchMsg;

@implementation ReYunChannel
typedef enum {
    INSTALL = 0,            //安装时发送
    REGISTER = 1,          //注册时发送
    STARTUP = 2,            //每次启动都发送
    LOGGEDIN = 3,          //登陆时发送
    EVENT= 4,               //event发送
    PAYMENT= 5,             //payment
    REGED= 6,               //reged
    GETTIME= 7,              //gettime
    HEARTBEAD = 8            //心跳发送。
    
} CommandFunc;
-(void)dealloc
{
    [_ServerConnection release];
    [_receivedData release];
    [super dealloc];
}
+(ReYunChannel *)sharedClick{
    if (!reYunChannelaClick) {
        reYunChannelaClick = [[ReYunChannel alloc] init];
    }
    return reYunChannelaClick;
}
-(id)init
{
    self=[super init];
    if (self) {
        [self getServersTime];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive)name:UIApplicationWillResignActiveNotification object:nil];
    }
    return self;
}
- (void)applicationWillResignActive
{
    [self performSelector:@selector(sendURLConnectionAgain) withObject:nil afterDelay:30];
}
//开启安装模式
+ (void)InstallMessage{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    NSInteger alreadinstall = [[installInfo objectForKey:@"alreadyinstall"] intValue];
    if (alreadinstall !=1) {
        [installInfo setInteger:1 forKey:@"alreadyinstall"];
        [[ReYunChannel sharedClick] SendBODYMessage:INSTALL];
    }
}
#pragma mark 调用——————————————————
+ (void)initWithAppId:(NSString *)appId withChannelId:(NSString *)channelId
{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    [installInfo setObject:appId forKey:@"InstallappKey"];
    [installInfo setObject:channelId forKey:@"channelID"];
    
    [self InstallMessage];//安装调用
    //每次启动时调用；包括第一次启动。
    [[ReYunChannel sharedClick] SendBODYMessage:STARTUP];
    [[ReYunChannel sharedClick] heartBeatSendMessage:TRUE];
    
}
#pragma mark 获得用户信息接口——————————————
//注册成功后调用
+ (void)setRegisterWithAccountID:(NSString *)account{
    [[ReYunChannel sharedClick] setAccountid:account];//账号
    [[ReYunChannel sharedClick] SendBODYMessage:REGED];//
}
//登陆成功后调用
+ (void)setLoginWithAccountID:(NSString *)account{
    [[ReYunChannel sharedClick] setAccountid:account];//账号
    [[ReYunChannel sharedClick] SendBODYMessage:LOGGEDIN];
}
+(void)setPayment:(NSString *)transactionId paymentType:(NSString*)paymentType currentType:(NSString*)currencyType currencyAmount:(float)currencyAmount{
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
    
    NSString* currencyAmountStr = [NSString stringWithFormat:@"%f",currencyAmount];
    [installInfo setValue:currencyAmountStr forKey:@"currencyAmount"];
    [[ReYunChannel sharedClick] SendBODYMessage:PAYMENT];
}

//自定义事件分析
+(void)setEvent:(NSString *)eventName{
    //    if([self isBlankString:eventName])
    //    {
    //        NSLog(@"%@",@"不能为空或空格");
    //    }
    
    [[ReYunChannel sharedClick] setEventName:eventName];//事件名称
    [[ReYunChannel sharedClick] SendBODYMessage:EVENT];
    
}
//+ (BOOL)isBlankString:(NSString *)string{
//    if (string == nil) {
//
//        return YES;
//
//    }
//    if (string == NULL) {
//
//        return YES;
//
//    }
//    if ([string isKindOfClass:[NSNull class]]) {
//
//        return YES;
//
//    }
//    if ([[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length]==0) {
//
//        return YES;
//
//    }
//    return NO;
//}


-(void)heartBeatSendMessage:(BOOL)isBeadOpen{
    if (isBeadOpen == TRUE) {
        //[userdefault synchronize];
        //多次调用会启动多个心跳值，增加判断每次登陆只调用一次
        [[ReYunChannel sharedClick] heartBeadFun];
    }
}
-(void)heartBeadFun{
    if (sendCatchMsg > 0) {
        [self sendURLConnectionAgain];
    }
    //   [[ReYunChannel sharedClick] SendBODYMessage:HEARTBEAD];
    sendCatchMsg++;
    NSUserDefaults* userdefault = [NSUserDefaults standardUserDefaults];
    NSInteger cycleHertTime = [[userdefault objectForKey:@"heartCountTime"] intValue];
    cycleHertTime =300;
    [self performSelector:@selector(heartBeadFun) withObject:nil afterDelay:cycleHertTime];
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
# define NLOG(name) NSLog(@"%@",name);
# define NLOGn(name) NSLog(name);
#pragma mark - 网络请求————————————
// 整理包体消息qc
-(void)SendBODYMessage:(CommandFunc)COMDFunc {
    
    NSString *body;
    NSString* urlStr;
    if (COMDFunc == INSTALL) {
        body = [self ArrangeDeviceInfo];
        urlStr = [NSString stringWithFormat:@"%@/receive/track/install",checkversionurl];
        NLOGn(@"INSTALL__________");
    }else if(COMDFunc == STARTUP){
        body = [self ArrangeMessageSTARTUP];
        urlStr = [NSString stringWithFormat:@"%@/receive/track/startup",checkversionurl];
        NLOGn(@"STARTUP___________");
    }else if(COMDFunc == REGED){
        body = [self ArrangeMessageReged];
        urlStr = [NSString stringWithFormat:@"%@/receive/track/register",checkversionurl];
        
        NLOGn(@"REGED————————————");
    }else if(COMDFunc == LOGGEDIN){
        body = [self ArrangeMessageLOGGEDIN];
        urlStr = [NSString stringWithFormat:@"%@/receive/track/loggedin",checkversionurl];
        
        NLOGn(@"LOGGEDIN____________");
    }else if(COMDFunc == HEARTBEAD){
        body = [self ArrangeMessageHeartBead];
        urlStr = [NSString stringWithFormat:@"%@/receive/track/heartbeat",checkversionurl];
        
        NLOGn(@"HEARTBEAD————————————");
    }else if(COMDFunc == PAYMENT){
        body = [self ArrangeMessagePayment];
        urlStr = [NSString stringWithFormat:@"%@/receive/track/payment",checkversionurl];
        
        NLOGn(@"Payment___________");
    }else if(COMDFunc == EVENT){
        body = [self ArrangeMessageEvent];
        urlStr = [NSString stringWithFormat:@"%@/receive/track/event",checkversionurl];
        NLOGn(@"EVENT___________");
    }
    else if(COMDFunc == GETTIME){
        urlStr = [NSString stringWithFormat:@"%@/receive/gettime",checkversionurl];
    }
    //    else if(COMDFunc == TASK){
    //    }
    
    _groupId=[[ChannelDataBase sharedMyDataBase] getGroupID];
    _groupId++;
    //    NSLog(@"groupID:%d",_groupId);
    [[ChannelDataBase sharedMyDataBase] insertData:body groupID:_groupId];
    [self sendURLConnection:urlStr];
    //创建JSON
    
}
//发送网络请求
-(void)sendURLConnection:(NSString*) newUrl{
    //    [self sendURLConnectionAgain];
    NSString *url = newUrl;
    NSArray *array=[[ChannelDataBase sharedMyDataBase] fillData];
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
        _reYunChannelmarginTime=[[installInfo objectForKey:@"marginTime"] longLongValue];
    }
}
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response  {
    if (arrayCount>0) {
        for (int i = 0; i<arrayCount; i++) {
            if (i>=100) {
                break;
            }
            NSInteger changeID = [[ChannelDataBase sharedMyDataBase] getID];
            [[ChannelDataBase sharedMyDataBase] changeSaveMark:0 groupid:changeID];
            [[ChannelDataBase sharedMyDataBase] removeData];
        }
        arrayCount = 0;
        
        
    }
    else{
        static long long i=0;
        NSLog(@"接收完响应:%lld %@",i,response);
        _haveURL=YES;//当网络请求成功时开启循环调用网络请求
        //发送成功后将currentSendDate对应body值设置为空
        
        NSInteger changeId=[[ChannelDataBase sharedMyDataBase] getGroupID];
        [[ChannelDataBase sharedMyDataBase] changeSaveMark:0 groupid:changeId];
        [[ChannelDataBase sharedMyDataBase] removeData];
        //NSLog(@"changeID!!!!!!!!!!!!!!!!%d",_ch   angeId);
        [_receivedData setLength:0];
        
        [[ReYunChannel sharedClick] sendURLConnectionAgainTransition];
        i++;
    }
}
-(void)sendURLConnectionAgainTransition{
    [self performSelector:@selector(sendURLConnectionAgain) withObject:nil afterDelay:20];
}
-(void)sendURLConnectionAgain{
    NSString *url = [NSString stringWithFormat:@"%@/receive/batch",checkversionurl];
    ;
    NSArray *array=[[ChannelDataBase sharedMyDataBase] fillData];
    NSMutableDictionary* finalDic = [[NSMutableDictionary alloc] init];
    NSMutableArray * afterArr = [[NSMutableArray alloc] init];
    NSString* dataStr = [NSString stringWithFormat:@"{\"from\":\"track\",\"appid\":\"%@\",\"data\":[",[self GetUDId]];
    if ([array count]>0 ) {
        for (int i=0; i<[array count]; i++) {
            dataStr = [dataStr stringByAppendingString:[array objectAtIndex:i]];
            if ((i+1)!=[array count]) {
                dataStr = [dataStr stringByAppendingString:@","];
            }
            if (i>=100) {
                break;
            }
            
            
            
        }
        dataStr = [dataStr stringByAppendingString:@"]"];
        dataStr = [dataStr stringByAppendingString:@"}"];
        //     NSString *str = [writer stringWithObject:dataStr];//dic就是你将要转换成字典，而returnString就是齐刷刷的json数据了
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
        //新添加的
        NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
        NSString* user_Id = [installInfo objectForKey:@"InstallappKey"];
        
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

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data  {
    //NSLog(@"data%@",data);
    [_receivedData appendData:data];
    NSDictionary* dic = (NSDictionary*)data;
    NSLog(@"%@",dic);
    NSString *mmmmmmm = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"%@",mmmmmmm);
    NSError* error = nil;
    NSDictionary* photo = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];//NSData类型的实例转成JSONObject
    NSLog(@"%@",photo);
    
    NSMutableArray *allKey = [[NSMutableArray alloc]init];
    id object;
    NSEnumerator * enumer = [photo keyEnumerator];//先得到里面所有的键值   objectEnumerator得到里面的对象  keyEnumerator得到里面的键值
    while (object=[enumer nextObject])//遍历输出
    {
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
-(void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error  {
    static int i=1;
    NSLog(@"数据接收错误:%d  %@",i++,error);
    _haveURL=NO;
}
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
//获取终端型号信息
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
//获取手机卡信息
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
// 检查渠道商
-(NSString*)GetChannel_Id{
    NSString* chanelID = nil;
    NSUserDefaults* installInfo = [NSUserDefaults standardUserDefaults];
    //  当渠道有值的时候可以显示
    NSString* channelLocal = [installInfo objectForKey:@"channelID"];
    if([channelLocal length]>0){
        chanelID = channelLocal;
    }
    else{
        chanelID = @"_default_";
    }
    return chanelID;
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
//获得当前时间
-(NSString*)currentTime{
    
    NSTimeInterval nowtime = [[NSDate date] timeIntervalSince1970];
    long long dataTime = [[NSNumber numberWithDouble:nowtime] longLongValue]; // 将double转为long long型
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:(dataTime + _reYunChannelmarginTime)];
    NSString *currentTime = [formatter stringFromDate:date];
    //NSLog(@"___________________currentTime:%@",currentTime);
    [formatter release];
    return currentTime;
}

//==============================================数据层//
#pragma mark  instal---------------
// 安装信息的布置//安装后第一次启动调用
-(NSString*)ArrangeDeviceInfo {
    
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    NSString* user_Id = [installInfo objectForKey:@"InstallappKey"];
    NSDictionary *contextDic = [[NSMutableDictionary alloc] init];
    [contextDic setValue:[self GetUDId] forKey:@"deviceid"];
    [contextDic setValue:[self GetChannel_Id] forKey:@"channelid"];
    [contextDic setValue:[self getIdFa] forKey:@"idfa"];
    [contextDic setValue:[self getIdFv] forKey:@"idfv"];
    
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
#pragma mark  STARTUP---------------
// DAU信息的布置   每次启动时调用；包括第一次启动。
- (NSString*)ArrangeMessageSTARTUP{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    NSString* user_Id = [installInfo objectForKey:@"InstallappKey"];
    NSDictionary *contextDic = [[NSMutableDictionary alloc] init];
    [contextDic setValue:[self GetUDId] forKey:@"deviceid"];
    [contextDic setValue:[self getIdFa] forKey:@"idfa"];
    [contextDic setValue:[self getIdFv] forKey:@"idfv"];
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

#pragma mark  reged---------------
// 用户成功注册返回后调用
-(NSString*)ArrangeMessageReged {
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    NSString* user_Id = [installInfo objectForKey:@"InstallappKey"];
    NSString *accountid=[installInfo objectForKey:@"accountid"];
    
    NSDictionary *contextDic = [[NSMutableDictionary alloc] init];
    [contextDic setValue:[self GetUDId] forKey:@"deviceid"];
    [contextDic setValue:[self GetChannel_Id] forKey:@"channelid"];
    [contextDic setValue:[self getIdFa] forKey:@"idfa"];
    [contextDic setValue:[self getIdFv] forKey:@"idfv"];
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
#pragma mark loggedin——————————————————
//在用户成功登录返回后调用
-(NSString *)ArrangeMessageLOGGEDIN{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    NSString * user_Id = [installInfo objectForKey:@"InstallappKey"];
    NSString *accountid=[installInfo objectForKey:@"accountid"];
    
    NSDictionary *contextDic = [[NSMutableDictionary alloc] init];
    [contextDic setValue:[self GetUDId] forKey:@"deviceid"];
    [contextDic setValue:[self GetChannel_Id] forKey:@"channelid"];
    [contextDic setValue:[self getIdFa] forKey:@"idfa"];
    [contextDic setValue:[self getIdFv] forKey:@"idfv"];
    
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
-(NSString*)ArrangeMessageHeartBead{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    NSString* user_Id = [installInfo objectForKey:@"InstallappKey"];
    NSString* accountid=[installInfo objectForKey:@"accountid"];
    if ([accountid length]==0) {
        accountid = @"unknown";
    }
    NSDictionary *contextDic = [[NSMutableDictionary alloc] init];
    [contextDic setValue:[self GetUDId] forKey:@"deviceid"];
    [contextDic setValue:[self getIdFa] forKey:@"idfa"];
    [contextDic setValue:[self getIdFv] forKey:@"idfv"];
    [contextDic setValue:[self GetChannel_Id] forKey:@"channelid"];
    
    
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

#pragma mark payment——————————————————
//用户充值之后调用
-(NSString *)ArrangeMessagePayment{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    NSString * user_Id = [installInfo objectForKey:@"InstallappKey"];
    NSString *accountid=[installInfo objectForKey:@"accountid"];
    //    NSString *amount=[installInfo objectForKey:@"amount"];//用户成功充值，充值的金额
    NSString *transactionIdStr = [installInfo objectForKey:@"transactionId"];
    NSString *paymentTypestr = [installInfo objectForKey:@"paymentType"];
    NSString *currenctyTypestr = [installInfo objectForKey:@"currenctyType"];
    NSString *currencyAmountStr = [installInfo objectForKey:@"currencyAmount"];
    
    NSDictionary *contextDic = [[NSMutableDictionary alloc] init];
    [contextDic setValue:[self GetUDId] forKey:@"deviceid"];
    [contextDic setValue:[self getIdFa] forKey:@"idfa"];
    [contextDic setValue:[self getIdFv] forKey:@"idfv"];
    [contextDic setValue:transactionIdStr forKey:@"transactionId"];
    [contextDic setValue:paymentTypestr forKey:@"paymentType"];
    [contextDic setValue:currenctyTypestr forKey:@"currencytype"];
    [contextDic setValue:currencyAmountStr forKey:@"currencyAmount"];
    [contextDic setValue:@"unknown" forKey:@"virtualcoinamount"];
    [contextDic setValue:@"unknown" forKey:@"iapname"];
    [contextDic setValue:@"unknown" forKey:@"iapamount"];
    [contextDic setValue:[self GetChannel_Id] forKey:@"channelid"];
    
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
#pragma mark event——————————————————
//事件发生之后调用
-(NSString *)ArrangeMessageEvent{
    NSUserDefaults *installInfo = [NSUserDefaults standardUserDefaults];
    NSString* user_Id = [installInfo objectForKey:@"InstallappKey"];
    NSString* accountid=[installInfo objectForKey:@"accountid"];
    NSString *eventName=[installInfo objectForKey:@"eventName"];
    
    NSDictionary *contextDic = [[NSMutableDictionary alloc] init];
    [contextDic setValue:[self GetUDId] forKey:@"deviceid"];
    [contextDic setValue:[self GetChannel_Id] forKey:@"channelid"];
    [contextDic setValue:[self getIdFa] forKey:@"idfa"];
    [contextDic setValue:[self getIdFv] forKey:@"idfv"];
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
    return body;
    
}

@end
