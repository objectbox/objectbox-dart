import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:objectbox/objectbox.dart';

import 'model.dart';
import 'objectbox.g.dart';

class Benchmark extends BenchmarkBase {
  final int iterations;

  Benchmark(String name, {int iterations = 1, double coefficient = 1})
      : iterations = iterations,
        super(name, emitter: Emitter(iterations, coefficient));

  @override
  void exercise() {
    for (var i = 0; i < iterations; i++) {
      runIteration(i);
    }
  }

  @override
  void run() => runIteration(0);

  void runIteration(int iteration) {}
}

class Emitter implements ScoreEmitter {
  static const usInSec = 1000000;

  final int iterations;
  final double coefficient;

  const Emitter(this.iterations, this.coefficient);

  @override
  void emit(String testName, double value) {
    final timePerIter = value / iterations;
    final timePerUnit = timePerIter * coefficient;
    print('$testName(Single iteration): ${format(timePerIter)} us.');
    print('$testName(Time per unit): ${format(timePerUnit)} us.');
    print('$testName(Runs per second): ${format(usInSec / timePerIter)}.');
    print('$testName(Units per second): ${format(usInSec / timePerUnit)}.');
  }

  String format(double num) => num.toStringAsFixed(2);
}

class DbBenchmark extends Benchmark {
  static final String dbDir = 'benchmark-db';
  final Store store;
  late final Box<TestEntity> box;

  DbBenchmark(String name, {int iterations = 1, double coefficient = 1})
      : store = Store(getObjectBoxModel(), directory: dbDir),
        super(name, iterations: iterations, coefficient: coefficient) {
    box = Box<TestEntity>(store);
  }

  @override
  void teardown() {
    store.close();
    final dir = Directory(dbDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

List<TestEntity> prepareTestEntities(int count, {bool assignedIds = false}) =>
    List<TestEntity>.generate(count,
        (i) => TestEntity(assignedIds ? i + 1 : 0, 'Entity #$i', i, i, i / 2),
        growable: false);
