import 'package:objectbox_benchmark/benchmark.dart';
import 'package:objectbox_benchmark/objectbox.g.dart';

const count = 10000;

void main() {
  Put().report();
  PutInTx().report();
  PutMany().report();
  PutAsync().report();
  PutAsync2().report();
  PutAsync3().report();
  PutQueued().report();
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
  void runIteration(int i) => Future.wait(items.map(box.putAsync));
}

// This is slightly different (slower) then the [PutAsync] - all futures are
// prepared beforehand, only then it starts to wait for them to complete.
class PutAsync2 extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  PutAsync2()
      : super('${PutAsync2}[wait(map().toList())] ',
            iterations: 1, coefficient: 1 / count);

  @override
  void runIteration(int i) {
    final futures = items.map(box.putAsync).toList(growable: false);
    Future.wait(futures);
  }
}

class PutAsync3 extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  PutAsync3() : super('${PutAsync3}[wait(putAsync(i))]', iterations: count);

  @override
  void runIteration(int i) => Future.wait([box.putAsync(items[i])]);
}

class PutQueued extends DbBenchmark {
  final items = prepareTestEntities(count, assignedIds: true);

  PutQueued() : super('${PutQueued}', iterations: count);

  @override
  void run() {
    items.forEach(box.putQueued);
    store.awaitAsyncSubmitted();
  }
}
