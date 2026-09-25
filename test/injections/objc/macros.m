// A log line with the app's prefix.
#define LOG(format, ...) NSLog(@"[app] " format, ##__VA_ARGS__)
#define DESCRIBE(object) [object description]

#pragma mark - Accounts
#pragma clang diagnostic ignored "-Wunused-macros"

static NSString *const name = @"accounts";
