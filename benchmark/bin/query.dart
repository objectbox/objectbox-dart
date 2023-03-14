import 'package:objectbox_benchmark/benchmark.dart';
import 'package:objectbox_benchmark/model.dart';
import 'package:objectbox_benchmark/objectbox.g.dart';

const count = 10000;

void main() async {
  await QueryFind().report();
  await QueryFindAsync().report();
  await QueryFindIds().report();
  await QueryFindIdsAsync().report();
  await QueryStream().report();
}

class QueryBenchmark extends DbBenchmark {
  static const expectedCount = count / 5;
  late final Query<TestEntity> query;

  QueryBenchmark(String name) : super(name, coefficient: 1 / expectedCount);

  @override
  void setup() {
    box.putMany(prepareTestEntities(count));
    query = box
        .query(TestEntity_.tInt
            .lessOrEqual((count / 10).floor())
            .or(TestEntity_.tInt.greaterThan(count - (count / 10).floor())))
        .build();

    if (query.count() != expectedCount) {
      throw Exception('Unexpected number of query results '
          '${query.count()} vs expected $expectedCount');
    }
  }

  @override
  void teardown() {
    query.close();
    super.teardown();
  }
}

class QueryFind extends QueryBenchmark {
  QueryFind() : super('$QueryFind');

  @override
  void runIteration(int iteration) => query.find();
}

class QueryFindAsync extends QueryBenchmark {
  QueryFindAsync() : super('$QueryFindAsync');

  @override
  Future<void> runIteration(int iteration) => query.findAsync();
}

class QueryFindIds extends QueryBenchmark {
  QueryFindIds() : super('$QueryFindIds');

  @override
  void runIteration(int iteration) => query.findIds();
}

class QueryFindIdsAsync extends QueryBenchmark {
  QueryFindIdsAsync() : super('$QueryFindIdsAsync');

  @override
  Future<void> runIteration(int iteration) => query.findIdsAsync();
}

/// Stream where visitor is running in Dart isolate.
class QueryStream extends QueryBenchmark {
  QueryStream() : super('$QueryStream');

  @override
  Future<void> runIteration(int iteration) => query.stream().toList();
}
