#import "NSExceptionCatcher.h"

id _Nullable TPCatchException(id _Nullable (^block)(void)) {
    @try {
        return block();
    } @catch (NSException *exception) {
        return nil;
    }
}
