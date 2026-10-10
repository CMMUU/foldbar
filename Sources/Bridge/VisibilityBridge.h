#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Runtime adapter for the macOS 27 menu-bar visibility assertion.
/// This object never writes system preferences. Its lifetime owns the assertion.
@interface FBVisibilitySession : NSObject
+ (BOOL)isSupported;
- (void)beginAllowingBundles:(NSArray<NSString *> *)bundles
                 completion:(void (^)(NSError * _Nullable error))completion;
- (void)restore;
@end
NS_ASSUME_NONNULL_END
