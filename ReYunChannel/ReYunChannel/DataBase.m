//
//  DataBase.m
//  ReYunChannel
//
//  Created by yun on 14/12/26.
//  Copyright (c) 2014年 reyun. All rights reserved.
//

#import "DataBase.h"
#import "FMDatabase.h"
@implementation DataBase
{
    FMDatabase *_database;
}
static DataBase * _sharedMyDataBase;
+(DataBase *)sharedMyDataBase{
    @synchronized(self){
        if (!_sharedMyDataBase) {
            _sharedMyDataBase=[[self alloc]init];
        }
    }
    return _sharedMyDataBase;
}
-(id)init
{
    self=[super init];
    if (self) {
        [self createDataBase];
        [self createTable];
    }
    return self;
}
-(void)createDataBase{
    _database=[[FMDatabase alloc]initWithPath:[NSString stringWithFormat:@"%@ReYunSDK.db",[NSString stringWithFormat:@"%@/Library/Caches/",NSHomeDirectory()]]];
    if (![_database open]) {
        NSLog(@"数据库打开失败");
    }else{
        
    }
}
-(void)createTable{
    [_database open];
    [_database executeUpdate:@"create table SDKTable(groupID integer,save integer,body text)"];
    [_database close];
}
-(void)insertData:(NSString *)body groupID:(NSInteger)Id
{
    [_database open];
    [_database executeUpdate:@"insert into SDKTable values(?,?,?)",[NSNumber numberWithInteger:Id],@"1",body];
    [_database close];
    
}
-(NSArray *)fillData{
    [_database open];
    NSMutableArray * dataArray=[NSMutableArray array];
    FMResultSet *res=[_database executeQuery:@"select * from SDKTable"];// where save=?",@"1"
    while ([res next]) {
        NSString *body=[res stringForColumn:@"body"];
        [dataArray addObject:body];
    }
    [_database close];
    return dataArray;
}
-(NSInteger)getGroupID{
    [_database open];
    int groupId=0;
    FMResultSet *res =[_database executeQuery:@"select groupID from SDKTable order by groupID desc limit 1"];//asc
    while ([res next]) {
        if ([res intForColumn:@"groupID"] != 0) {
            groupId=[res intForColumn:@"groupID"];
        }
    }
    [_database close];
    return groupId;
    
}
//降序
-(NSInteger)getID
{
    [_database open];
    int groupId=0;
    FMResultSet *res =[_database executeQuery:@"select groupID from SDKTable order by groupID asc limit 1"];//asc
    while ([res next]) {
        if ([res intForColumn:@"groupID"] != 0) {
            groupId=[res intForColumn:@"groupID"];
        }
    }
    [_database close];
    return groupId;
}
-(void)changeSaveMark:(int)num groupid:(int)Id//默认0，删除0，未发送改变1保存
{
    [_database open];
    [_database executeUpdate:@"update SDKTable set save=? where groupID=?",[NSNumber numberWithInt:num],[NSNumber numberWithInt:Id]];
    [_database close];
}
-(void)removeData{
    [_database open];
    if ([_database executeQuery:@"select body from SDKTable"]) {
        [_database executeUpdate:@"delete from SDKTable where save=?",@"0"];
    }
    [_database close];
    
}
@end
