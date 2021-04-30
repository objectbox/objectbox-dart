import 'package:objectbox_benchmark/benchmark.dart';
import 'package:objectbox_benchmark/model.dart';
import 'package:objectbox_benchmark/objectbox.g.dart';

const count = 10000;

void main() {
  QueryFind().report();
  QueryFindIds().report();
  QueryStream().report();
}

class QueryBenchmark extends DbBenchmark {
  late final Query<TestEntity> query;

  QueryBenchmark(String name)
      : super(name, iterations: 1, coefficient: 1 / count);

  @override
  void setup() {
    box.putMany(prepareTestEntities(count));
    query = box
        .query(TestEntity_.tInt
            .lessOrEqual((count / 10).floor())
            .or(TestEntity_.tInt.greaterThan(count - (count / 10).floor())))
        .build();

    if (query.count() != count / 5) {
      throw Exception('Unexpected number of query results '
          '${query.count()} vs expected ${count / 5}');
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
  void run() => query.find();
}

class QueryFindIds extends QueryBenchmark {
  QueryFindIds() : super('${QueryFindIds}');

  @override
  void run() => query.findIds();
}

class QueryStream extends QueryBenchmark {
  QueryStream() : super('${QueryStream}');

  @override
  void run() async => await Future.wait([query.stream().toList()]);
}
