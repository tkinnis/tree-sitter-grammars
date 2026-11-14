<?php

namespace Cards;

enum Suit: string implements HasLabel
{
    case Hearts = 'H';
    case Spades = 'S';

    const Wild = self::Spades;

    public function label(): string
    {
        return ucfirst($this->name);
    }
}

enum Status
{
    case Active;
}

class Deck
{
    public $cards;
}
