import 'package:objectbox_benchmark/benchmark.dart';

void main() async {
  await Get().report();
  await GetAsync().report();
  await GetMany().report();
  await GetManyAsync().report();
  await GetAll().report();
  await GetAllAsync().report();
}

const iterationsGet = 1000;

class Get extends DbBenchmark {
  Get() : super('$Get', iterations: iterationsGet);

  @override
  void runIteration(int i) => box.get(i + 1);

  @override
  void setup() => box.putMany(prepareTestEntities(iterations));
}

class GetAsync extends DbBenchmark {
  GetAsync() : super('$GetAsync', iterations: iterationsGet);

  @override
  void runIteration(int i) => box.getAsync(i + 1);

  @override
  void setup() => box.putMany(prepareTestEntities(iterations));
}

const getManyCount = 10000;

class GetMany extends DbBenchmark {
  late final List<int> ids;

  GetMany() : super('$GetMany', iterations: 1, coefficient: 1 / getManyCount);

  @override
  void runIteration(int i) => box.getMany(ids);

  @override
  void setup() => ids = box.putMany(prepareTestEntities(getManyCount));
}

class GetManyAsync extends DbBenchmark {
  late final List<int> ids;

  GetManyAsync()
    : super('$GetManyAsync', iterations: 1, coefficient: 1 / getManyCount);

  @override
  void runIteration(int i) => box.getManyAsync(ids);

  @override
  void setup() => ids = box.putMany(prepareTestEntities(getManyCount));
}

class GetAll extends DbBenchmark {
  GetAll() : super('$GetAll', iterations: 1, coefficient: 1 / getManyCount);

  @override
  void runIteration(int i) => box.getAll();

  @override
  void setup() => box.putMany(prepareTestEntities(getManyCount));
}

class GetAllAsync extends DbBenchmark {
  GetAllAsync()
    : super('$GetAllAsync', iterations: 1, coefficient: 1 / getManyCount);

  @override
  void runIteration(int i) => box.getAllAsync();

  @override
  void setup() => box.putMany(prepareTestEntities(getManyCount));
}
