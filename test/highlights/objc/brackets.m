@class Forward;

@protocol Shape <NSObject>
@end

@interface Box : NSObject <NSCopying>
@property (nonatomic) NSArray<NSString *> *names;
@property (nonatomic) id<Shape> shape;
@end

int below(int i, int n) {
  return i < n && n > 0;
}

size_t width = sizeof_list(NSArray<NSString *>);
