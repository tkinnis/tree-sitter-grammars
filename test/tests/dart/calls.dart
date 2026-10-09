import 'package:test/test.dart';

void main() async {
  await test('awaited', () {});

  group('arrow', () => test('in an arrow body', () {}));

  group('async', () async {
    await test('awaited in a group', () {});
  });
}
