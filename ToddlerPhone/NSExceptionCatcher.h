#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Runs the block, catching Objective-C exceptions (which Swift cannot).
/// Returns the block's result, or nil if an exception was thrown.
id _Nullable TPCatchException(id _Nullable (^block)(void));

NS_ASSUME_NONNULL_END
