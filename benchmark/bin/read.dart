import 'package:objectbox_benchmark/benchmark.dart';

void main() async {
  await Get().report();
  await GetAsync().report();
  await GetMany().report();
  await GetManyAsync().report();
  await GetAll().report();
  await GetAllAsync().report();
}

class Get extends DbBenchmark {
  Get() : super('$Get', iterations: 1000);

  @override
  void runIteration(int i) => box.get(i + 1);

  @override
  void setup() => box.putMany(prepareTestEntities(iterations));
}

class GetAsync extends DbBenchmark {
  GetAsync() : super('$GetAsync', iterations: 1000);

  @override
  void runIteration(int i) => box.getAsync(i + 1);

  @override
  void setup() => box.putMany(prepareTestEntities(iterations));
}

class GetMany extends DbBenchmark {
  static final count = 10000;
  late final List<int> ids;

  GetMany() : super('$GetMany', iterations: 1, coefficient: 1 / count);

  @override
  void runIteration(int i) => box.getMany(ids);

  @override
  void setup() => ids = box.putMany(prepareTestEntities(count));
}

class GetManyAsync extends DbBenchmark {
  static final count = 10000;
  late final List<int> ids;

  GetManyAsync()
      : super('$GetManyAsync', iterations: 1, coefficient: 1 / count);

  @override
  void runIteration(int i) => box.getManyAsync(ids);

  @override
  void setup() => ids = box.putMany(prepareTestEntities(count));
}

class GetAll extends DbBenchmark {
  static final count = 10000;

  GetAll() : super('$GetAll', iterations: 1, coefficient: 1 / count);

  @override
  void runIteration(int i) => box.getAll();

  @override
  void setup() => box.putMany(prepareTestEntities(count));
}

class GetAllAsync extends DbBenchmark {
  static final count = 10000;

  GetAllAsync() : super('$GetAllAsync', iterations: 1, coefficient: 1 / count);

  @override
  void runIteration(int i) => box.getAllAsync();

  @override
  void setup() => box.putMany(prepareTestEntities(count));
}
