import 'package:objectbox_benchmark/benchmark.dart';
import 'package:objectbox_benchmark/objectbox.g.dart';

const count = 10000;

void main() {
  Put().report();
  PutInTx().report();
  PutMany().report();
  PutAsync().report();
  PutAsync2().report();
}

class Put extends DbBenchmark {
  static const count = 1000;
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

  // TODO do we still need waiting to call store_await_async_submitted?
  @override
  void runIteration(int i) => Future.wait(items.map(box.putAsync));
}

class PutAsync2 extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  PutAsync2()
      : super('${PutAsync2}[map().toList, then wait()] ',
            iterations: 1, coefficient: 1 / count);

  @override
  void runIteration(int i) {
    // This is slightly different (slower) then the [PutAsync] - all futures are
    // prepared beforehand, only then it starts to wait for them to complete.
    final futures = items.map(box.putAsync).toList(growable: false);
    Future.wait(futures);
    // TODO do we still need waiting to call store_await_async_submitted?
  }
}
