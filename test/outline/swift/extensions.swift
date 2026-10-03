import Testing

struct OuterSuite {
    @Test func works() {}
}

extension OuterSuite {
    @Test func alsoWorks() {}

    struct InnerSuite {
        @Test func nested() {}
    }
}

extension Outer.Inner {
    func reachedByAPath() {}
}

extension Array<Int> {
    func total() -> Int { 0 }
}

extension Collection where Element: Equatable {
    func allEqual() -> Bool { true }
}

@Test func topLevel() {}
