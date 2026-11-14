enum class Direction : unsigned char {
    North,
    South = 4,
};

enum Color {
    Red,
};

typedef enum {
    Read,
    Write,
} Mode;

namespace geometry {
enum struct Axis { X, Y };
}

class Grid {
    enum Cell { Empty, Wall };
};

typedef enum Level { Low } Level;

typedef enum Shade { Dark } Tone;

typedef enum Level LevelAlias;

typedef class { int x; } Anonymous;

typedef decltype(1) Number;

template <typename T>
struct Holder {
    typedef typename T::value_type Value;
};

typedef auto Deduced;

typedef int Index;

typedef std::size_t Size;

typedef unsigned long Count;

typedef [:reflected:] Spliced;

typedef struct { int y; } Point;

typedef vector<int> Numbers;

typedef Index Position;

typedef union { int whole; } Whole;
