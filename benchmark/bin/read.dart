import 'package:objectbox_benchmark/benchmark.dart';

void main() {
  Get().report();
  GetMany().report();
  GetAll().report();
}

class Get extends DbBenchmark {
  Get() : super('${Get}', iterations: 1000);

  @override
  void runIteration(int i) => box.get(i + 1);

  @override
  void setup() => box.putMany(prepareTestEntities(iterations));
}

class GetMany extends DbBenchmark {
  static final count = 10000;
  late final List<int> ids;

  GetMany() : super('${GetMany}', iterations: 1, coefficient: 1 / count);

  @override
  void runIteration(int i) => box.getMany(ids);

  @override
  void setup() => ids = box.putMany(prepareTestEntities(count));
}

class GetAll extends DbBenchmark {
  static final count = 10000;

  GetAll() : super('${GetAll}', iterations: 1, coefficient: 1 / count);

  @override
  void runIteration(int i) => box.getAll();

  @override
  void setup() => box.putMany(prepareTestEntities(count));
}
