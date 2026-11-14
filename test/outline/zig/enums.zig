const std = @import("std");

pub const Suit = enum(u8) {
    hearts,
    spades = 4,

    pub fn isRed(self: Suit) bool {
        return self == .hearts;
    }
};

const Card = struct {
    suit: Suit,
};

const Value = union(enum) {
    number: u8,
};

var count: u8 = 0;

const Count = u8;

const Level = enum(u2) {
    low,
    high,
    _,
};

const Holder = struct {
    const Inner = enum {
        first,
    };
};

const Pair = struct { const Side = enum { left, right }; };

const Anonymous = @TypeOf(enum { lone });

const enumerated = 3;

const total = enumerated;

pub const limit: Count = total;

extern "c" var errno: Count;
