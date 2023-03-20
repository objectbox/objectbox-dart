import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';

import 'model.dart';
import 'objectbox.g.dart';

class Benchmark {
  final String name;
  final int iterations;
  final double coefficient;
  final watch = Stopwatch();
  final Emitter emitter;

  /// Create a benchmark with the given [name], starts measuring total run time.
  ///
  /// ```dart
  /// await Benchmark('Name', coefficient: 1 / count).report();
  /// ```
  ///
  /// Call [report] on this to await results.
  ///
  /// Runs the [runIteration] function at least [iterations] times, defaults to
  /// 1. If possible, leave this at the default. The benchmark is automatically
  /// re-run a) to warm up until at least 100 ms have passed (e.g. to avoid
  /// caching skewing results) and b) to measure until at least 2 seconds have
  /// passed. This is similar to how Dart's benchmark_harness and various other
  /// benchmarking libraries in other languages work.
  ///
  /// Set a fraction in [coefficient] to multiply the measured value of a run
  /// with, defaults to 1. Use this if a run calls a to be measured function
  /// multiple times (e.g. `1 / times`) to get the duration of a single call.
  ///
  /// Results are printed to the command line.
  Benchmark(this.name, {this.iterations = 1, this.coefficient = 1})
      : emitter = Emitter(iterations, coefficient) {
    print('-------------------------------------------------------------');
    print(
        '$name(iterations):          ${Emitter._format(iterations.toDouble(), decimalPoints: 0)}');
    print(
        '$name(unit count):          ${Emitter._format(iterations / coefficient, decimalPoints: 0)}');
    // Measure the total time of the test - if it's too high, you should
    // decrease the number of iterations. Expected time is between 2 and 3 sec.
    watch.start();
  }

  /// Not measured setup code executed prior to [run] getting called.
  void setup() {}

  /// Called after all [run] calls have completed, measures total time of the
  /// benchmark.
  ///
  /// A method overriding this must call this.
  @mustCallSuper
  void teardown() {
    final millis = watch.elapsedMilliseconds;
    final color = millis > 3000 ? '\x1B[31m' : '';
    print('$name(benchmark run time):     '
        '$color${Emitter._format(millis.toDouble(), suffix: ' ms')}\x1B[0m');
  }

  /// Calls [runIteration] [iterations] of times.
  Future<void> run() async {
    for (var i = 0; i < iterations; i++) {
      final result = runIteration(i);
      if (result is Future) {
        await result;
      }
    }
    return Future.value();
  }

  /// A single test iteration, given [iteration] index starting from 0.
  FutureOr<void> runIteration(int iteration) {
    throw UnimplementedError('Please override runIteration() or run()');
  }

  /// Runs [f] for at least [minimumMillis] milliseconds.
  Future<double> _measureFor(Function f, int minimumMillis, bool warmUp) async {
    final minimumMicros = minimumMillis * 1000;
    var iter = 0;
    final watch = Stopwatch()..start();
    var elapsed = 0;
    while (elapsed < minimumMicros) {
      await f();
      elapsed = watch.elapsedMicroseconds;
      iter++;
    }
    if (!warmUp) {
      // Print how often f had to be re-run to reach minimum run time.
      final reruns = iter - 1;
      print('$name(re-runs):             '
          '${Emitter._format(reruns.toDouble(), decimalPoints: 0)}');
    }
    return elapsed / iter;
  }

  /// Measures the score for the benchmark and returns it.
  ///
  /// See [report] for details.
  @nonVirtual
  Future<double> _measure() async {
    setup();
    // Warmup for at least 100ms. Discard result.
    await _measureFor(run, 100, true);
    // Run the benchmark for at least 2000ms.
    var result = await _measureFor(run, 2000, false);
    teardown();
    return result;
  }

  /// Starts the benchmark and waits for the result.
  ///
  /// - Calls [setup], then
  /// - repeatedly calls [run] for at least 100 ms to warm up to avoid effects
  /// e.g. due to caching,
  /// - then calls [run] repeatedly until at least 2000 ms have passed to ensure
  /// stable results and collects the average elapsed time of a call (if run
  /// multiple times), then
  /// - calls [teardown] and returns the result.
  @nonVirtual
  Future<void> report() async {
    emitter.emit(name, await _measure());
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
    print('$testName(single iteration):       '
        '${_format(timePerIter, suffix: ' us')}');
    print('$testName(per unit):               '
        '${_format(timePerUnit, suffix: ' us')}');
    print('$testName(iterations / second): '
        '${_format(usInSec / timePerIter)}');
    print('$testName(units / second):      '
        '${_format(usInSec / timePerUnit)}');
  }

  // Simple number formatting, maybe use a lib?
  // * the smaller the number, the more decimal places it has (one up to four).
  // * large numbers use thousands separator (defaults to non-breaking space).
  static String _format(double num,
      {String thousandsSeparator = ' ',
      int? decimalPoints,
      String suffix = ''}) {
    decimalPoints ??= num < 1
        ? 4
        : num < 10
            ? 3
            : num < 100
                ? 2
                : num < 1000
                    ? 1
                    : 0;

    var str = num.toStringAsFixed(decimalPoints);
    if (num >= 1000) {
      // add thousands separators, efficiency doesn't matter here...
      final digitsReversed = str.split('').reversed.toList(growable: false);
      str = '';
      for (var i = 0; i < digitsReversed.length; i++) {
        if (i > 0 && i % 3 == 0) str = '$thousandsSeparator$str';
        str = '${digitsReversed[i]}$str';
      }
    }
    str += suffix;
    while (str.length < 10) {
      str = ' $str';
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
