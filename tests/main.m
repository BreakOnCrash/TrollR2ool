#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property(strong, nonatomic) UIWindow *window;

@end

@implementation AppDelegate

// Disable debugger function
void disableDebugger() {
    __asm__("mov x3, #0"
            "mov x2, #0"
            "mov x1, #0"
            "mov x0, #31"  /* PT_DENY_ATTACH 31 (0x1f) */
            "mov x16, #26" /* ptrace syscall number 26 (0x1a) */
            "svc #0x80");
}

// Application launch entry point
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Disable debugger
    disableDebugger();

    // Create a simple UI to display the message
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    UIViewController *rootViewController = [[UIViewController alloc] init];
    rootViewController.view.backgroundColor = [UIColor whiteColor];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 280, 50)];
    label.text = @"Hackme!!! :)";
    label.textAlignment = NSTextAlignmentCenter;

    [rootViewController.view addSubview:label];
    self.window.rootViewController = rootViewController;
    [self.window makeKeyAndVisible];

    return YES;
}

@end

// Main entry point
int main(int argc, char *argv[]) {
    NSString *appDelegateClassName;
    @autoreleasepool {
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
