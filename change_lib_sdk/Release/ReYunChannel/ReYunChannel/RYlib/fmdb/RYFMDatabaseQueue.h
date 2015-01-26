//
//  FMDatabasePool.h
//  fmdb
//
//  Created by August Mueller on 6/22/11.
//  Copyright 2011 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "sqlite3.h"

@class RYFMDatabase;

@interface RYFMDatabaseQueue : NSObject {
    NSString            *_path;
    dispatch_queue_t    _queue;
    RYFMDatabase          *_db;
}

@property (retain) NSString *path;

+ (id)databaseQueueWithPath:(NSString*)aPath;
- (id)initWithPath:(NSString*)aPath;
- (void)close;

- (void)inDatabase:(void (^)(RYFMDatabase *db))block;

- (void)inTransaction:(void (^)(RYFMDatabase *db, BOOL *rollback))block;
- (void)inDeferredTransaction:(void (^)(RYFMDatabase *db, BOOL *rollback))block;

#if SQLITE_VERSION_NUMBER >= 3007000
// NOTE: you can not nest these, since calling it will pull another database out of the pool and you'll get a deadlock.
// If you need to nest, use FMDatabase's startSavePointWithName:error: instead.
- (NSError*)inSavePoint:(void (^)(RYFMDatabase *db, BOOL *rollback))block;
#endif

@end

