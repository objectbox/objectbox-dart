import 'package:objectbox_benchmark/benchmark.dart';
import 'package:objectbox_benchmark/model.dart';
import 'package:objectbox_benchmark/objectbox.g.dart';

const count = 10000;

void main() async {
  await QueryFind().report();
  await QueryFindIds().report();
  await QueryStream().report();
  await QueryStreamIsolate().report();
}

class QueryBenchmark extends DbBenchmark {
  static const expectedCount = count / 5;
  late final Query<TestEntity> query;

  QueryBenchmark(String name)
      : super(name, iterations: 1, coefficient: 1 / expectedCount);

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
  QueryFind() : super('${QueryFind}');

  @override
  Future<void> run() async {
    query.find();
    return Future.value();
  }
}

class QueryFindIds extends QueryBenchmark {
  QueryFindIds() : super('${QueryFindIds}');

  @override
  Future<void> run() async => query.findIds();
}

/// Stream where visitor is running in native code.
class QueryStream extends QueryBenchmark {
  QueryStream() : super('${QueryStream}');

  @override
  Future<void> run() async => await query.stream().toList();
}

/// Stream where visitor is running in Dart isolate.
class QueryStreamIsolate extends QueryBenchmark {
  QueryStreamIsolate() : super('${QueryStreamIsolate}');

  @override
  Future<void> run() async {
    var stream = await query.streamAsync();
    await stream.toList();
  }
}
