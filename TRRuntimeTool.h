#import <Foundation/Foundation.h>

@interface AppRuntimeTool : NSObject
+ (NSArray *)listProcess;
+ (NSString *)lookupPtraceSvc:(pid_t)pid;
@end