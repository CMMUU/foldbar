#import "VisibilityBridge.h"
#import <dlfcn.h>

// Selector signatures independently checked against this Mac's runtime.
// These are private Apple interfaces, isolated here for replacement per OS.
@protocol FBSystemConfiguration
- (instancetype)initWithAllowedSystemItems:(NSArray<NSNumber *> *)items
                 allowedBundleIdentifiers:(NSArray<NSString *> *)bundles;
@end
@protocol FBSystemAssertion
- (void)activateWithConfiguration:(id)configuration
               completionHandler:(void (^)(NSError *error))completion;
- (void)invalidate;
@end

@implementation FBVisibilitySession {
    id<FBSystemAssertion> _token;
}

+ (BOOL)isSupported {
    if (NSProcessInfo.processInfo.operatingSystemVersion.majorVersion != 27) return NO;
    static void *framework;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        framework = dlopen("/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore", RTLD_LAZY | RTLD_LOCAL);
    });
    if (!framework) return NO;
    Class configuration = NSClassFromString(@"MBAssessmentModeConfiguration");
    Class assertion = NSClassFromString(@"MBAssessmentModeAssertion");
    return [configuration instancesRespondToSelector:@selector(initWithAllowedSystemItems:allowedBundleIdentifiers:)]
        && [assertion instancesRespondToSelector:@selector(activateWithConfiguration:completionHandler:)]
        && [assertion instancesRespondToSelector:@selector(invalidate)];
}

- (void)beginAllowingBundles:(NSArray<NSString *> *)bundles completion:(void (^)(NSError *))completion {
    [self restore];
    if (![FBVisibilitySession isSupported]) {
        completion([NSError errorWithDomain:@"FoldBar" code:1 userInfo:@{NSLocalizedDescriptionKey: @"当前系统不支持此版本的收起功能。"}]);
        return;
    }
    @try {
        // Preserve the nine core system items supported by the current runtime.
        NSMutableArray *systemItems = [NSMutableArray array];
        for (NSInteger i = 0; i <= 8; i++) [systemItems addObject:@(i)];
        id<FBSystemConfiguration> allocation = [NSClassFromString(@"MBAssessmentModeConfiguration") alloc];
        id configuration = [allocation initWithAllowedSystemItems:systemItems allowedBundleIdentifiers:bundles];
        _token = [[NSClassFromString(@"MBAssessmentModeAssertion") alloc] init];
        if (!configuration || !_token) {
            [self restore];
            completion([NSError errorWithDomain:@"FoldBar" code:2 userInfo:@{NSLocalizedDescriptionKey: @"无法创建菜单栏会话，请保持全部展开。"}]);
            return;
        }
        [_token activateWithConfiguration:configuration completionHandler:completion];
    } @catch (NSException *exception) {
        [self restore];
        completion([NSError errorWithDomain:@"FoldBar" code:3 userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"菜单栏接口发生变化。"}]);
    }
}

- (void)restore {
    if (!_token) return;
    @try { [_token invalidate]; } @catch (NSException *exception) { }
    _token = nil;
}

- (void)dealloc { [self restore]; }
@end
