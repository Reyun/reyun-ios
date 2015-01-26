//
//  DataBase.h
//  ReYunChannel
//
//  Created by yun on 14/12/26.
//  Copyright (c) 2014年 reyun. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ChannelDataBase : NSObject

+(ChannelDataBase *)sharedMyDataBase;
//创建数据库
-(void)createDataBase;
//创建表
-(void)createTable;
//插入数据
-(void)insertData:(NSString *)body groupID:(NSInteger)Id;
//读取数据
-(NSArray *)fillData;
//删除旧数据
-(void)removeData;
//标记未成功发送的数据为1
-(void)changeSaveMark:(int)num groupid:(int)Id;
//标记每行降序
-(NSInteger)getGroupID;
//升序
-(NSInteger)getID;

@end
