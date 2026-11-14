package com.example.cards

enum class Suit(val symbol: String) {
    HEARTS("H"),
    SPADES("S") {
        override fun label() = "spades"
    };

    open fun label() = symbol
}

@JvmInline
private enum class Order {
    ASCENDING,
    DESCENDING,
}

class Deck<T>(val cards: List<T>) : Iterable<T> where T : Any

class Hand

interface Dealer {
    fun deal()
}

data class Card(val suit: Suit)

class Shelf : Iterable<String> by emptyList()

class Box<T>

enum class Code(val value: Int)

enum class Blank
