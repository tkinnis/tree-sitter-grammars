indirect enum Expression {
    case number(Int), sum(Expression, Expression)
    case negation(Expression)

    func evaluate() -> Int { 0 }
}

enum Suit: String {
    case hearts = "H"
}

struct Deck {
    enum Order { case ascending }
    let size: Int
}

actor Dealer {}

extension Suit {
    var symbol: String { rawValue }
}
