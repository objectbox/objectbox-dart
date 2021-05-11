import 'package:objectbox/objectbox.dart';
import 'package:objectbox_benchmark/benchmark.dart';
import 'package:objectbox_benchmark/model.dart';

void main() {
  SetupSingle().report();
  SetupMulti().report();
}

// ~200k per second
class SetupSingle extends DbBenchmark {
  SetupSingle() : super('${SetupSingle}');

  @override
  void runIteration(int i) async {
    final sub = store.watch<TestEntity>().listen((event) {});
    await sub.cancel();
  }
}

// ~175k per second with the original [Store.watchAll()]
// ~240k per second with [Store.entityChanges]
class SetupMulti extends DbBenchmark {
  SetupMulti() : super('${SetupMulti}');

  @override
  void runIteration(int i) async {
    final sub = store.entityChanges.listen((event) {});
    await sub.cancel();
  }
}
