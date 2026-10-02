@class Forward;

@interface Box : NSObject <NSCopying>
@property (nonatomic) NSArray<NSString *> *names;
@end

int below(int i, int n) {
  return i < n && n > 0;
}
