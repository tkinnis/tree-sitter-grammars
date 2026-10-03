import 'dart:async';
import 'dart:math';

import 'package:checks/checks.dart';
import 'package:test/test.dart';

import '../tool/src/pool.dart';

void main() {
  group('pooledEach', () {
    test('completes each item as its own task ends, before the tasks of '
        'items before it', () async {
      final gates = [Completer<void>(), Completer<void>(), Completer<void>()];
      final ended = <int>[];

      final results = pooledEach([0, 1, 2], (index) async {
        await gates[index].future;
        return 'item $index';
      }, limit: 3);
      for (final (index, result) in results.indexed) {
        unawaited(result.then((_) => ended.add(index)));
      }
      gates[2].complete();
      check(await results[2]).equals('item 2');
      gates[0].complete();
      gates[1].complete();

      check(
        await Future.wait(results),
      ).deepEquals(['item 0', 'item 1', 'item 2']);
      check(ended).deepEquals([2, 0, 1]);
    });

    test('runs at most the limit at once, starting them in order', () async {
      final started = <int>[];
      var running = 0;
      var most = 0;

      await Future.wait(
        pooledEach([0, 1, 2, 3, 4], (index) async {
          started.add(index);
          most = max(most, ++running);
          await Future<void>.delayed(const Duration(milliseconds: 5));
          running--;
          return index;
        }, limit: 2),
      );

      check(started).deepEquals([0, 1, 2, 3, 4]);
      check(most).equals(2);
    });

    test('fails only the future of a task that throws, and runs the '
        'rest', () async {
      final results = pooledEach([0, 1, 2], (index) async {
        if (index == 1) throw StateError('item 1');
        return index;
      }, limit: 1);

      check(await results[0]).equals(0);
      await check(results[1]).throws<StateError>();
      check(await results[2]).equals(2);
    });
  });

  group('pooled', () {
    test('returns every result in the order of the items', () async {
      final results = await pooled([3, 1, 2], (delay) async {
        await Future<void>.delayed(Duration(milliseconds: delay));
        return delay * 10;
      });

      check(results).deepEquals([30, 10, 20]);
    });

    test('fails with what a task threw once every task has ended', () async {
      final ended = <int>[];

      await check(
        pooled([0, 1, 2], (index) async {
          await Future<void>.delayed(Duration(milliseconds: index));
          ended.add(index);
          if (index == 0) throw StateError('item 0');
          return index;
        }, limit: 1),
      ).throws<StateError>();
      check(ended).deepEquals([0, 1, 2]);
    });
  });
}
