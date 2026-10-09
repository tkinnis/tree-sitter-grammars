import 'package:test/test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('top level', () {});

  testWidgets('a widget', (tester) async {});

  group('outer', () {
    test('in outer', () {});

    group("inner, double quoted", () async {
      test('in inner', () {});

      testWidgets('widget in inner', (tester) async {});
    });

    group('with a named argument', () {
      test('in it', () {});
    }, skip: true);
  });

  group('after', () {
    test('back at one level', () {});
  });
}
