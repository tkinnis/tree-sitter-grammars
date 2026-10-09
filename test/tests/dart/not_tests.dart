import 'package:test/test.dart';

// test('in a comment', () {});

void main() {
  test.skip('a member of test');
  foo.test('a member of foo', () {});
  final text = "test('in a string', () {})";
  testing('a near miss', () {});
  group.only('a member of group', () {
    test('inside it', () {});
  });
  if (test(value)) {}
  test('the one real test', () {});
}
