import 'dart:io';

import 'package:objectbox/objectbox.dart';

import 'model.dart';
import 'objectbox.g.dart';

class Executor {
  final Store store;

  /*late final*/
  Box<TestEntity> box;

  /// list of runtimes indexed by function name
  final times = <String, List<Duration>>{};

  Executor(Directory dbDir)
      : store = Store(getObjectBoxModel(), directory: dbDir.path) {
    box = Box<TestEntity>(store);
  }

  void close() => store.close();

  R _track<R>(String fnName, R Function() fn) {
    final watch = Stopwatch();

    watch.start();
    final result = fn();
    watch.stop();

    times[fnName] ??= <Duration>[];
    times[fnName].add(watch.elapsed);
    return result;
  }

  void _print(List<dynamic> varArgs) {
    print(varArgs.join('\t'));
  }

  void printTimes([List<String> functions]) {
    functions ??= times.keys.toList();

    // print the whole data as a table
    _print(['Function', 'Runs', 'Average ms', 'All times']);
    for (final fun in functions) {
      final fnTimes = times[fun];

      final sum = fnTimes.map((d) => d.inMicroseconds).reduce((v, e) => v + e);
      final avg = sum.toDouble() / fnTimes.length.toDouble() / 1000;
      final timesCols = fnTimes.map((d) => d.inMicroseconds.toDouble() / 1000);
      _print([fun, fnTimes.length, avg, ...timesCols]);
    }
  }

  List<TestEntity> prepareData(int count) {
    return _track('prepareData', () {
      final result = <TestEntity>[];
      for (var i = 0; i < count; i++) {
        result.add(TestEntity.full('Entity #$i', i, i, i.toDouble()));
      }
      return result;
    });
  }

  void putMany(List<TestEntity> items) {
    _track('putMany', () => box.putMany(items));
  }

  void updateAll(List<TestEntity> items) {
    _track('updateAll', () => box.putMany(items));
  }

  List<TestEntity> readAll() {
    return _track('readAll', () => box.getAll());
  }

  void removeAll() {
    _track('removeAll', () => box.removeAll());
  }

  void changeValues(List<TestEntity> items) {
    _track('changeValues', () => items.forEach((item) => item.tLong *= 2));
  }
}
