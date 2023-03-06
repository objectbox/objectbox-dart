import 'dart:async';

import 'package:objectbox_benchmark/benchmark.dart';
import 'package:objectbox_benchmark/model.dart';
import 'package:objectbox_benchmark/objectbox.g.dart';

const count = 10000;

void main() async {
  await Put().report();
  await PutInTx().report();
  await PutMany().report();
  await PutAsyncSequential().report();
  await PutAsyncParallel().report();
  await PutAsyncToList().report();
  await PutAsyncAwait().report();
  await PutQueued().report();
  await RunInTx().report();
  await RunInTxAsync().report();
  await RunAsync().report();
}

class Put extends DbBenchmark {
  static const count = 100;
  final items = prepareTestEntities(count, assignedIds: true);

  Put() : super('$Put', iterations: count);

  @override
  void runIteration(int i) => box.put(items[i]);
}

class PutInTx extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  PutInTx() : super('$PutInTx', iterations: 1, coefficient: 1 / count);

  @override
  void runIteration(int i) =>
      store.runInTransaction(TxMode.write, () => items.forEach(box.put));
}

class PutMany extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  PutMany() : super('$PutMany', iterations: 1, coefficient: 1 / count);

  @override
  void runIteration(int i) => box.putMany(items);
}

/// Runs putAsync one-by-one, use to measure time of a single call.
class PutAsyncSequential extends DbBenchmark {
  static const count = 10;
  final items = prepareTestEntities(count, assignedIds: true);

  PutAsyncSequential() : super('$PutAsyncSequential', iterations: count);

  @override
  FutureOr<void> runIteration(int iteration) => box.putAsync(items[iteration]);
}

/// Runs many putAsync calls in parallel and waits until the last one completes,
/// use to assert parallelization capability.
class PutAsyncParallel extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  PutAsyncParallel() : super('$PutAsyncParallel');

  @override
  Future<void> run() async => await Future.wait(items.map(box.putAsync));
}

/// This is slightly different (slower) then [PutAsyncParallel] - all futures are
/// prepared beforehand, only then it starts to wait for them to complete.
class PutAsyncToList extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  PutAsyncToList() : super('$PutAsyncToList');

  @override
  Future<void> run() async {
    final futures = items.map(box.putAsync).toList(growable: false);
    await Future.wait(futures);
    store.awaitAsyncSubmitted();
  }
}

class PutAsyncAwait extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  PutAsyncAwait() : super('$PutAsyncAwait');

  @override
  Future<void> run() async {
    items.forEach((item) async => await box.putAsync(item));
    store.awaitAsyncSubmitted();
  }
}

class PutQueued extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  PutQueued() : super('$PutQueued', iterations: count);

  @override
  Future<void> run() async {
    items.forEach(box.putQueued);
    store.awaitAsyncSubmitted();
  }
}

class RunInTx extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  RunInTx() : super('$RunInTx');

  @override
  void runIteration(int i) {
    store.runInTransaction(TxMode.write, () {
      box.putMany(items);
      return box.getAll();
    });
  }
}

class RunInTxAsync extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  RunInTxAsync() : super('$RunInTxAsync');

  @override
  Future<List<TestEntity>> runIteration(int iteration) async {
    return store.runInTransactionAsync(TxMode.write,
        (Store store, List<TestEntity> param) {
      final box = store.box<TestEntity>();
      box.putMany(param);
      return box.getAll();
    }, items);
  }
}

class RunAsync extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  RunAsync() : super('$RunAsync');

  @override
  Future<List<TestEntity>> runIteration(int iteration) {
    return store.runAsync((Store store, List<TestEntity> param) {
      final box = store.box<TestEntity>();
      box.putMany(param);
      return box.getAll();
    }, items);
  }
}
