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

typedef enum Shade {
    SHADE_DARK,
} Tone;

typedef enum Level LevelAlias;

typedef enum {
    ACCESS_OWNER,
} Access, *AccessPointer;

typedef enum {
    POINTED_FIRST,
} *Pointed;

typedef struct {
    int x;
} Point;

typedef union {
    int whole;
    float part;
} Number;

typedef unsigned int Count;

typedef int Index;

typedef Count Total;

typedef ATOMIC(int) Counter;

enum {
    ANONYMOUS_FLAG,
};

int brightness(enum Color color) {
    return 0;
}
