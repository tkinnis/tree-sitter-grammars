var state: enum { idle, running } = .idle;

extern "c" var foreign: enum(c_int) { ok, failed };

const Mode: type = enum {
    read,
    write,
};

const State = enum {
    idle,
    running,
    _,

    pub fn isRunning(self: State) bool {
        return self == .running;
    }
};
