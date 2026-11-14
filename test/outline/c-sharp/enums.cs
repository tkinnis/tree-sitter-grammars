namespace Cards;

[Flags]
public enum Suit : byte
{
    Hearts = 1,
    Spades = 2,
}

public class Deck
{
    public enum Order { Ascending, Descending }

    public void Shuffle() { }
}
