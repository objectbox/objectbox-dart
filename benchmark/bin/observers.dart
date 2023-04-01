import 'dart:async';

import 'package:objectbox/objectbox.dart';
import 'package:objectbox_benchmark/benchmark.dart';
import 'package:objectbox_benchmark/model.dart';

void main() async {
  await SetupSingle().report();
  await SetupSingleBasedOnMulti().report();
  await SetupMulti().report();
  await SetupMultiExisting().report();
}

// ~200k per second
// ~165k with ReceivePort reuse (see this commit)
class SetupSingle extends DbBenchmark {
  SetupSingle() : super('$SetupSingle');

  @override
  void runIteration(int i) async {
    final sub = store.watch<TestEntity>().listen((event) {});
    await sub.cancel();
  }
}

// ~400k per second
// ~370k with ReceivePort reuse (see this commit)
class SetupSingleBasedOnMulti extends DbBenchmark {
  late StreamSubscription multiSub;

  SetupSingleBasedOnMulti() : super('$SetupSingleBasedOnMulti');

  @override
  void runIteration(int i) async {
    final sub = store.watch<TestEntity>().listen((event) {});
    await sub.cancel();
  }

  @override
  void setup() {
    // see implementation - prepares a stream beforehand
    multiSub = store.entityChanges.listen((event) {});
    super.setup();
  }

  @override
  void teardown() {
    multiSub.cancel();
    super.teardown();
  }
}

// ~175k per second with the original [Store.watchAll()]
// ~240k per second with [Store.entityChanges]
// ~610k with ReceivePort reuse (see this commit)
class SetupMulti extends DbBenchmark {
  SetupMulti() : super('$SetupMulti');

  @override
  void runIteration(int i) async {
    final sub = store.entityChanges.listen((event) {});
    await sub.cancel();
  }
}

// ~650k per second
// ~615k with ReceivePort reuse (see this commit)
class SetupMultiExisting extends DbBenchmark {
  late StreamSubscription multiSub;

  SetupMultiExisting() : super('$SetupMultiExisting');

  @override
  void runIteration(int i) async {
    final sub = store.entityChanges.listen((event) {});
    await sub.cancel();
  }

  @override
  void setup() {
    // see implementation - prepares a stream beforehand
    multiSub = store.entityChanges.listen((event) {});
    super.setup();
  }

  @override
  void teardown() {
    multiSub.cancel();
    super.teardown();
  }
}
