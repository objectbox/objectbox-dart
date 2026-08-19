// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:objectbox_benchmark/benchmark.dart';
import 'package:objectbox_benchmark/model.dart';
import 'package:objectbox_benchmark/objectbox.g.dart';

const count = 10000;

void main() async {
  await Put().report();
  await PutInTx().report();
  await PutMany().report();
  await PutManyAsync().report();
  await PutAndGetManyAsync().report();
  await PutQueuedAwaitResult().report();
  await PutQueued().report();
  await PutAsync().report();
  await PutAndGetAsync().report();
  await PutQueuedAwaitResultParallel().report();
  await PutQueuedParallel().report();
  await PutAsyncParallel().report();
  await PutAsyncToList().report();
  await PutAsyncAwait().report();
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

const putManyCount = 200000;

class PutInTx extends DbBenchmark {
  final items = prepareTestEntities(putManyCount, assignedIds: true);

  PutInTx() : super('$PutInTx', iterations: 1, coefficient: 1 / putManyCount);

  @override
  void runIteration(int i) =>
      store.runInTransaction(TxMode.write, () => items.forEach(box.put));
}

class PutMany extends DbBenchmark {
  final items = prepareTestEntities(putManyCount, assignedIds: true);

  PutMany() : super('$PutMany', iterations: 1, coefficient: 1 / putManyCount);

  @override
  void runIteration(int i) => box.putMany(items);
}

class PutManyAsync extends DbBenchmark {
  final items = prepareTestEntities(putManyCount, assignedIds: true);

  PutManyAsync()
    : super('$PutManyAsync', iterations: 1, coefficient: 1 / putManyCount);

  @override
  void runIteration(int i) => box.putManyAsync(items);
}

class PutAndGetManyAsync extends DbBenchmark {
  final items = prepareTestEntities(putManyCount, assignedIds: true);

  PutAndGetManyAsync()
    : super(
        '$PutAndGetManyAsync',
        iterations: 1,
        coefficient: 1 / putManyCount,
      );

  @override
  void runIteration(int i) => box.putAndGetManyAsync(items);
}

const putAsyncCount = 10;

/// Runs putAsync one-by-one, use to measure time of a single call.
class PutQueuedAwaitResult extends DbBenchmark {
  final items = prepareTestEntities(putAsyncCount, assignedIds: true);

  PutQueuedAwaitResult()
    : super('$PutQueuedAwaitResult', iterations: putAsyncCount);

  @override
  FutureOr<void> runIteration(int iteration) =>
      box.putQueuedAwaitResult(items[iteration]);
}

/// Runs putQueued one-by-one, use to measure time of a single call.
class PutQueued extends DbBenchmark {
  final items = prepareTestEntities(putAsyncCount, assignedIds: true);

  PutQueued() : super('$PutQueued', iterations: putAsyncCount);

  @override
  FutureOr<void> runIteration(int iteration) {
    box.putQueued(items[iteration]);
    store.awaitQueueSubmitted();
  }
}

/// Runs putAsync one-by-one, use to measure time of a single call.
class PutAsync extends DbBenchmark {
  final items = prepareTestEntities(putAsyncCount, assignedIds: true);

  PutAsync() : super('$PutAsync', iterations: putAsyncCount);

  @override
  FutureOr<void> runIteration(int iteration) => box.putAsync(items[iteration]);
}

/// Runs one-by-one, use to measure time of a single call.
class PutAndGetAsync extends DbBenchmark {
  final items = prepareTestEntities(putAsyncCount, assignedIds: true);

  PutAndGetAsync() : super('$PutAndGetAsync', iterations: putAsyncCount);

  @override
  FutureOr<void> runIteration(int iteration) =>
      box.putAndGetAsync(items[iteration]);
}

const putAsyncParallelCount = 100;

/// Runs many PutQueuedAwaitResult calls in parallel and waits until the last one completes,
/// use to assert parallelization capability.
class PutQueuedAwaitResultParallel extends DbBenchmark {
  final items = prepareTestEntities(putAsyncParallelCount, assignedIds: true);

  PutQueuedAwaitResultParallel() : super('$PutQueuedAwaitResultParallel');

  @override
  Future<void> run() async =>
      await Future.wait(items.map(box.putQueuedAwaitResult));
}

/// Runs many putQueuedParallel calls in parallel and waits until the last one
/// completes, use to assert parallelization capability.
class PutQueuedParallel extends DbBenchmark {
  final items = prepareTestEntities(putAsyncParallelCount, assignedIds: true);

  PutQueuedParallel() : super('$PutQueuedParallel', iterations: 1);

  @override
  Future<void> run() async {
    items.forEach(box.putQueued);
    store.awaitQueueSubmitted();
  }
}

/// Runs many putAsync calls in parallel and waits until the last one completes,
/// use to assert parallelization capability.
class PutAsyncParallel extends DbBenchmark {
  final items = prepareTestEntities(putAsyncParallelCount, assignedIds: true);

  PutAsyncParallel() : super('$PutAsyncParallel', iterations: 1);

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
    final futures = items.map(box.putQueuedAwaitResult).toList(growable: false);
    await Future.wait(futures);
    store.awaitQueueSubmitted();
  }
}

class PutAsyncAwait extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  PutAsyncAwait() : super('$PutAsyncAwait');

  @override
  Future<void> run() async {
    for (var item in items) {
      await box.putQueuedAwaitResult(item);
    }
    store.awaitQueueSubmitted();
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
    return store.runInTransactionAsync(TxMode.write, (
      Store store,
      List<TestEntity> param,
    ) {
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
