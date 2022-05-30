import 'dart:async';

import 'package:objectbox_benchmark/benchmark.dart';
import 'package:objectbox_benchmark/model.dart';
import 'package:objectbox_benchmark/objectbox.g.dart';

const count = 10000;

void main() async {
  await Put().report();
  await PutInTx().report();
  await PutMany().report();
  await PutAsync().report();
  await PutAsync2().report();
  await PutAsync3().report();
  await PutQueued().report();
  await RunInTx().report();
  await RunInTxAsync().report();
}

class Put extends DbBenchmark {
  static const count = 100;
  final items = prepareTestEntities(count, assignedIds: true);

  Put() : super('${Put}', iterations: count);

  @override
  void runIteration(int i) => box.put(items[i]);
}

class PutInTx extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  PutInTx() : super('${PutInTx}', iterations: 1, coefficient: 1 / count);

  @override
  void runIteration(int i) =>
      store.runInTransaction(TxMode.write, () => items.forEach(box.put));
}

class PutMany extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  PutMany() : super('${PutMany}', iterations: 1, coefficient: 1 / count);

  @override
  void runIteration(int i) => box.putMany(items);
}

class PutAsync extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  PutAsync()
      : super('${PutAsync}[wait(map())] ',
            iterations: 1, coefficient: 1 / count);

  @override
  Future<void> run() async => await Future.wait(items.map(box.putAsync));
}

// This is slightly different (slower) then the [PutAsync] - all futures are
// prepared beforehand, only then it starts to wait for them to complete.
class PutAsync2 extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  PutAsync2()
      : super('${PutAsync2}[wait(map().toList())] ',
            iterations: 1, coefficient: 1 / count);

  @override
  Future<void> run() async {
    final futures = items.map(box.putAsync).toList(growable: false);
    await Future.wait(futures);
    store.awaitAsyncSubmitted();
  }
}

class PutAsync3 extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  PutAsync3() : super('${PutAsync3}[wait(putAsync(i))]', iterations: count);

  @override
  Future<void> run() async {
    items.forEach((item) async => await box.putAsync(item));
    store.awaitAsyncSubmitted();
  }
}

class PutQueued extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  PutQueued() : super('${PutQueued}', iterations: count);

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
    store.runInTransaction(TxMode.write, () => items.forEach(box.put));
  }
}

class RunInTxAsync extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  RunInTxAsync() : super('$RunInTxAsync');

  @override
  Future<void> runIteration(int iteration) {
    return store.runInTransactionAsync(TxMode.write,
        (Store store, List<TestEntity> items) {
      final box = store.box<TestEntity>();
      items.forEach(box.put);
    }, items);
  }
}
