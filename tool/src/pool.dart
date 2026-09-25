/// Runs asynchronous work over a list with bounded concurrency.
library;

import 'dart:io';
import 'dart:math';

/// Runs [task] over [items] with at most [limit] running at once, by
/// default one per processor, and returns the results in the order of
/// [items].
Future<List<R>> pooled<T, R>(
  List<T> items,
  Future<R> Function(T) task, {
  int? limit,
}) async {
  final results = List<R?>.filled(items.length, null);
  var next = 0;
  Future<void> worker() async {
    while (next < items.length) {
      final index = next++;
      results[index] = await task(items[index]);
    }
  }

  final workers = min(limit ?? Platform.numberOfProcessors, items.length);
  await Future.wait([for (var i = 0; i < workers; i++) worker()]);
  return results.cast<R>();
}
