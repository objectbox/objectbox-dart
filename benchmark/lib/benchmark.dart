import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:objectbox/objectbox.dart';

import 'model.dart';
import 'objectbox.g.dart';

class Benchmark extends BenchmarkBase {
  final int iterations;
  final double coefficient;
  final watch = Stopwatch();

  Benchmark(String name, {this.iterations = 1, this.coefficient = 1})
      : super(name, emitter: Emitter(iterations, coefficient)) {
    print('-------------------------------------------------------------');
    print('$name(iterations):       ${Emitter.format(iterations.toDouble())}');
    print(
        '$name(count):            ${Emitter.format(iterations / coefficient)}');
    // Measure the total time of the test - if it's too high, you should
    // decrease the number of iterations. Expected time is between 2 and 3 sec.
    watch.start();
  }

  @override
  void teardown() {
    final color = watch.elapsedMilliseconds > 3000 ? '\x1B[31m' : '';
    print('$name(total time taken): $color${watch.elapsed.toString()}\x1B[0m');
  }

  @override
  void exercise() => run();

  @override
  void run() {
    for (var i = 0; i < iterations; i++) runIteration(i);
  }

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
    print('$testName(Single iteration): ${format(timePerIter)} us');
    print('$testName(Runtime per unit): ${format(timePerUnit)} us');
    print('$testName(Runs per second):  ${format(usInSec / timePerIter)}');
    print('$testName(Units per second): ${format(usInSec / timePerUnit)}');
  }

  // Simple number formatting, maybe use a lib?
  // * the smaller the number, the more decimal places it has (one up to four).
  // * large numbers use thousands separator (defaults to non-breaking space).
  static String format(double num, [String thousandsSeparator = ' ']) {
    final decimalPoints = num < 1
        ? 4
        : num < 10
            ? 3
            : num < 100
                ? 2
                : num < 1000
                    ? 1
                    : 0;

    var str = num.toStringAsFixed(decimalPoints);
    if (num < 1000) return str;

    // add thousands separators, efficiency doesn't matter here...
    final digitsReversed = str.split('').reversed.toList(growable: false);
    str = '';
    for (var i = 0; i < digitsReversed.length; i++) {
      if (i > 0 && i % 3 == 0) str = '$thousandsSeparator$str';
      str = '${digitsReversed[i]}$str';
    }
    return str;
  }
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
    super.teardown();
  }
}

List<TestEntity> prepareTestEntities(int count, {bool assignedIds = false}) =>
    List<TestEntity>.generate(count,
        (i) => TestEntity(assignedIds ? i + 1 : 0, 'Entity #$i', i, i, i / 2),
        growable: false);
