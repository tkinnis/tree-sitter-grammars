package Cards is
   type Suit is (Hearts, Spades);

   type Bit is ('0', '1');

   type Rank is range 1 .. 13;

   type Card is record
      Of_Suit : Suit;
   end record;

   procedure Shuffle;
end Cards;
