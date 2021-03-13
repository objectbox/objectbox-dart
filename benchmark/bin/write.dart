import 'package:objectbox_benchmark/benchmark.dart';
import 'package:objectbox_benchmark/objectbox.g.dart';

void main() {
  Put().report();
  PutInTx().report();
  PutMany().report();
}

class Put extends DbBenchmark {
  final items = prepareTestEntities(1000, assignedIds: true);

  Put() : super('${Put}', iterations: 1000);

  @override
  void runIteration(int i) => box.put(items[i]);
}

class PutInTx extends Put {
  PutInTx() : super();

  @override
  void exercise() {
    store.runInTransaction(TxMode.write, () {
      for (var i = 0; i < iterations; i++) {
        box.put(items[i]);
      }
    });
  }
}

class PutMany extends DbBenchmark {
  static final batchSize = 10000;
  final items = prepareTestEntities(batchSize, assignedIds: true);

  PutMany() : super('${PutMany}', iterations: 1, coefficient: 1 / batchSize);

  @override
  void runIteration(int i) => box.putMany(items);
}
