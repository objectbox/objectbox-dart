import 'package:objectbox_benchmark/benchmark.dart';
import 'package:objectbox_benchmark/objectbox.g.dart';

void main() {
  Put().report();
  PutInTx().report();
  PutMany().report();
}

class Put extends DbBenchmark {
  static const count = 1000;
  final items = prepareTestEntities(count, assignedIds: true);

  Put() : super('${Put}', iterations: count);

  @override
  void runIteration(int i) => box.put(items[i]);
}

class PutInTx extends DbBenchmark {
  static const count = 1000;
  final items = prepareTestEntities(count, assignedIds: true);

  PutInTx() : super('${PutInTx}', iterations: count);

  @override
  void run() {
    store.runInTransaction(TxMode.write, () {
      for (var i = 0; i < items.length; i++) {
        box.put(items[i]);
      }
    });
  }
}

class PutMany extends DbBenchmark {
  static final count = 10000;
  final items = prepareTestEntities(count, assignedIds: true);

  PutMany() : super('${PutMany}', iterations: 1, coefficient: 1 / count);

  @override
  void runIteration(int i) => box.putMany(items);
}
