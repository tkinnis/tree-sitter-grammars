/// Runs asynchronous work over a list with bounded concurrency.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

/// Runs [task] over [items] with at most [limit] running at once, by
/// default one per processor, and returns the results in the order of
/// [items], once every task has ended; it fails with the first error a
/// task threw.
Future<List<R>> pooled<T, R>(
  List<T> items,
  Future<R> Function(T) task, {
  int? limit,
}) => Future.wait(pooledEach(items, task, limit: limit));

/// Runs [task] over [items] with at most [limit] running at once, by
/// default one per processor, starting them in the order of [items], and
/// returns the future of each item's result in that order, each completing
/// as its own task ends, with its result or the error it threw.
List<Future<R>> pooledEach<T, R>(
  List<T> items,
  Future<R> Function(T) task, {
  int? limit,
}) {
  final results = [for (final _ in items) Completer<R>()];
  var next = 0;
  Future<void> worker() async {
    while (next < items.length) {
      final result = results[next];
      final item = items[next++];
      try {
        result.complete(await task(item));
      } on Object catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    }
  }

  final workers = min(limit ?? Platform.numberOfProcessors, items.length);
  for (var i = 0; i < workers; i++) {
    unawaited(worker());
  }
  return [for (final result in results) result.future];
}
