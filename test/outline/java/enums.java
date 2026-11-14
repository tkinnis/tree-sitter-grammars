package com.example.cards;

public enum Suit {
    HEARTS("H"),
    SPADES("S") {
        @Override
        String label() {
            return "spades";
        }
    };

    private final String symbol;

    Suit(String symbol) {
        this.symbol = symbol;
    }

    String label() {
        return symbol;
    }
}

class Deck {
    enum Order { ASCENDING, DESCENDING }

    void shuffle() {}
}
