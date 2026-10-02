module Pick where

pick :: a -> [a] -> a
pick fallback items = case items of
  [] -> fallback
  (first : _) -> first
