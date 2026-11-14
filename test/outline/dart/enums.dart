enum Planet implements Comparable<Planet> {
  mercury(mass: 3.303e+23),
  venus(mass: 4.869e+24);

  const Planet({required this.mass});

  final double mass;

  @override
  int compareTo(Planet other) => mass.compareTo(other.mass);
}

enum Suit { hearts, spades }

class Deck {
  void shuffle() {}
}
