CREATE TYPE suit AS ENUM ('hearts', 'spades');

CREATE TABLE card (
  id INT,
  of_suit suit
);
