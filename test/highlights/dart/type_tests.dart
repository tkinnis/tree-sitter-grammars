String describe(Object value) {
  if (value is int) return 'int ${value + 1}';
  if (value is! String) return 'other';
  return 'string $value';
}
