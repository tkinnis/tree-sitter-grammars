enum Color {
    COLOR_RED,
    COLOR_GREEN = 2,
};

typedef enum {
    MODE_READ,
    MODE_WRITE,
} Mode;

typedef enum Level {
    LEVEL_LOW,
} Level;

typedef struct {
    int x;
} Point;

typedef unsigned int Count;

enum {
    ANONYMOUS_FLAG,
};

int brightness(enum Color color) {
    return 0;
}

typedef enum : long {
    ShapeCircle,
} Shape;

@interface Canvas
- (void)draw;
@end
