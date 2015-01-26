//
//  MyDataBase.h
//
//  Created by  lip on 13-10-9.
//  Copyright (c) 2013年 . All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RYDataBase : NSObject



+(RYDataBase *)sharedMyDataBase;
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
//标记每行升序
-(NSInteger)getGroupID;
//降序
-(NSInteger)getID;
@end
