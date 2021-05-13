import 'dart:cli';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:objectbox/objectbox.dart';

import 'model.dart';
import 'objectbox.g.dart';

class Benchmark {
  final String name;
  final int iterations;
  final double coefficient;
  final watch = Stopwatch();
  final Emitter emitter;

  Benchmark(this.name, {this.iterations = 1, this.coefficient = 1})
      : emitter = Emitter(iterations, coefficient) {
    print('-------------------------------------------------------------');
    print('$name(iterations):       ${Emitter._format(iterations.toDouble())}');
    print(
        '$name(count):            ${Emitter._format(iterations / coefficient)}');
    // Measure the total time of the test - if it's too high, you should
    // decrease the number of iterations. Expected time is between 2 and 3 sec.
    watch.start();
  }

  // Not measured setup code executed prior to the benchmark runs.
  void setup() {}

  @mustCallSuper
  void teardown() {
    final color = watch.elapsedMilliseconds > 3000 ? '\x1B[31m' : '';
    print('$name(total time taken): $color${watch.elapsed.toString()}\x1B[0m');
  }

  void run() async {
    for (var i = 0; i < iterations; i++) runIteration(i);
  }

  void runIteration(int iteration) async {}

  // Runs [f] for at least [minimumMillis] milliseconds.
  static Future<double> _measureFor(Function f, int minimumMillis) async {
    final minimumMicros = minimumMillis * 1000;
    var iter = 0;
    final watch = Stopwatch()..start();
    var elapsed = 0;
    while (elapsed < minimumMicros) {
      await f();
      elapsed = watch.elapsedMicroseconds;
      iter++;
    }
    return elapsed / iter;
  }

  // Measures the score for the benchmark and returns it.
  @nonVirtual
  Future<double> _measure() async {
    setup();
    // Warmup for at least 100ms. Discard result.
    await _measureFor(run, 100);
    // Run the benchmark for at least 2000ms.
    var result = await _measureFor(run, 2000);
    teardown();
    return result;
  }

  @nonVirtual
  void report() {
    emitter.emit(name, waitFor(_measure()));
  }
}

class Emitter {
  static const usInSec = 1000000;

  final int iterations;
  final double coefficient;

  const Emitter(this.iterations, this.coefficient);

  void emit(String testName, double value) {
    final timePerIter = value / iterations;
    final timePerUnit = timePerIter * coefficient;
    print('$testName(Single iteration): ${_format(timePerIter)} us');
    print('$testName(Runtime per unit): ${_format(timePerUnit)} us');
    print('$testName(Runs per second):  ${_format(usInSec / timePerIter)}');
    print('$testName(Units per second): ${_format(usInSec / timePerUnit)}');
  }

  // Simple number formatting, maybe use a lib?
  // * the smaller the number, the more decimal places it has (one up to four).
  // * large numbers use thousands separator (defaults to non-breaking space).
  static String _format(double num, [String thousandsSeparator = ' ']) {
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
  late final Store store;
  late final Box<TestEntity> box;

  DbBenchmark(String name, {int iterations = 1, double coefficient = 1})
      : super(name, iterations: iterations, coefficient: coefficient) {
    deleteDbDir();
    store = Store(getObjectBoxModel(), directory: dbDir);
    box = Box<TestEntity>(store);
  }

  @override
  void teardown() {
    store.close();
    deleteDbDir();
    super.teardown();
  }

  void deleteDbDir() {
    final dir = Directory(dbDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

List<TestEntity> prepareTestEntities(int count, {bool assignedIds = false}) =>
    List<TestEntity>.generate(count,
        (i) => TestEntity(assignedIds ? i + 1 : 0, 'Entity #$i', i, i, i / 2),
        growable: false);
