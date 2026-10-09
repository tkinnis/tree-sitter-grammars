import 'package:test/test.dart';

void group(String name, void Function() body) => body();

void main() {
  group('own group', () {
    test('after a rebinding', () {});
  });
}
