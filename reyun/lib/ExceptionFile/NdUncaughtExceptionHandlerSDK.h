//
//  ExceptionFile.h
//  hoolaisdk
//
//  Created by chen xiaodong on 13-3-12.
//  Copyright (c) 2013年 chenxiaodong. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "reyun.h"

@interface NdUncaughtExceptionHandler : NSObject {
    
}

+ (void)setDefaultHandler;
+ (NSUncaughtExceptionHandler*)getHandler;

@end