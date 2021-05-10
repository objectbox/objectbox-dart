import 'dart:async';

import 'package:objectbox/objectbox.dart';
import 'package:objectbox_benchmark/benchmark.dart';
import 'package:objectbox_benchmark/model.dart';

void main() {
  SetupSingle().report();
  SetupMulti().report();
}

// ~190k per second
class SetupSingle extends DbBenchmark {
  SetupSingle() : super('${SetupSingle}');

  @override
  void runIteration(int i) async {
    final sub = store.subscribe<TestEntity>().listen((event) {});
    await sub.cancel();
  }
}

// ~175k per second
class SetupMulti extends DbBenchmark {
  SetupMulti() : super('${SetupMulti}');

  @override
  void runIteration(int i) async {
    final sub = store.subscribeAll().listen((event) {});
    await sub.cancel();
  }
}
