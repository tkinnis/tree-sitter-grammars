export enum Direction {
  Up = 1,
  Down,
}

const enum Flag {
  None = 0,
  "Read-Only" = 1,
}

declare enum Remote {
  Origin,
}

namespace Cards {
  export enum Suit {
    Hearts = "H",
  }
}

class Deck {
  shuffle(): void {}
}
