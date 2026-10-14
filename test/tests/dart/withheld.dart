import 'package:test/test.dart';

void main() {
  group(name, () {
    test('named by a variable', () {});
  });

  group('$name interpolated', () {
    test('named by an interpolation', () {});
  });

  group('escaped \n', () {
    test('named by an escape', () {});
  });

  group(r'raw', () {
    test('named raw', () {});
  });

  for (final value in values) {
    test('in a loop', () {});
  }
  // dart format off
  test('one', () {}); test('two', () {});
  // dart format on
  setUp(() {
    test('in a callback', () {});
  });
}

void helper() {
  test('in a helper function', () {});
}

class Suite {
  void define() {
    test('in a method', () {});
  }
}
