import "package:test/test.dart";
import "package:objectbox/objectbox.dart";
import "entity.dart";
import 'test_env.dart';

void main() {
  TestEnv<TestEntityProperty> env;
  Box box;

  setUp(() {
    env = TestEnv(TestEntityProperty_OBXDefs, "query_property");
    box = env.box;
  });

  final integers = [0, 0, 1, 1, 2, 3, 4, 5];
  final integerList = integers.map((i) => TestEntityProperty.initIntegers(true, 1+i, 2+i, 3+i, 4+i, 5+i)).toList();
  final strings = ["string", "another", "string", "1withSuffix", "2withSuffix", "1withSuffix"];
  final stringList  = strings.map((s) => TestEntityProperty.initString(s)).toList();
  final floats = [ 0.1, 0.1, 0.1, 0.1, 0.1 ]; // [0, 0.0, 0.1, 0.2, 0.1];
  final floatList  = floats.map((f) => TestEntityProperty.initFloats(0.1+f, 0.1+f)).toList();

  final tBool = TestEntityProperty_.tBool;
  final tChar = TestEntityProperty_.tChar;
  final tByte = TestEntityProperty_.tByte;

  final tLong = TestEntityProperty_.tLong;
  final tInt = TestEntityProperty_.tInt;
  final tShort = TestEntityProperty_.tShort;
  final tIntegers = [ tLong, tInt, tShort ];

  final tFloat = TestEntityProperty_.tFloat;
  final tDouble = TestEntityProperty_.tDouble;
  final tFloats = [ tFloat, tDouble ];

  final tString = TestEntityProperty_.tString;

  test(".count (basic query)", () {
    box.putMany(integerList);
    box.putMany(stringList);
    box.putMany(floatList);

    tIntegers.forEach((i) {
      final queryInt = box.query((i as QueryIntegerProperty).greaterThan(0)).build();
      expect(queryInt.count(), 8);
      queryInt.close();
    });

    tFloats.forEach((f) {
      final queryFloat = box.query((f as QueryDoubleProperty).lessThan(1.0)).build();
      expect(queryFloat.count(), 5);
      queryFloat.close();
    });

    final queryString = box.query(tString.contains('t')).build();
    expect(queryString.count(), 6);
    queryString.close();

    final queryBool = box.query(tBool.equals(true)).build();
    expect(queryBool.count(), 8);
    queryBool.close();

    final queryChar = box.query(tChar.greaterThan(0)).build();
    expect(queryChar.count(), 8);
    queryChar.close();
  });

  test(".distinct, .count, .close property query", () {
    box.putMany(integerList);
    box.putMany(stringList);
    box.putMany(floatList);

    // int
    final query = box.query((tLong < 2) as Condition).build();

    for (int i=0; i<tIntegers.length; i++) {
      final queryInt = query.property(tLong);
      expect(queryInt.count(), 4);
      queryInt.close();
    }

    // TODO NPE on queryInt (no errors thrown), can't reuse queryInt, turn on when fixed (dart 2.6?)
//    final tLongDistinctCount = queryInt..distinct(true)..count();
//    expect(2, tLongDistinctCount);

    final queryInt2 = query.property(tLong);
    expect(queryInt2..distinct(true)..count(), 2);
    queryInt2.close();

    query.close();
  });

  test("query.property(E_.field) property query, type inference", () {
    box.putMany(integerList);
    box.putMany(stringList);
    box.putMany(floatList);

    final query = box.query((tLong < 2) as Condition).build();

    tIntegers.forEach((i) {
      final qp = query.property(i);
      expect(qp is IntegerPropertyQuery, true);
      qp.close();
    });

    tFloats.forEach((f) {
      final qp = query.property(f);
      expect(qp is DoublePropertyQuery, true);
      qp.close();
    });

    final qp = query.property(tString);
    expect(qp is StringPropertyQuery, true);
    qp.close();

  });

  test(".sum", () {
    box.putMany(integerList);

    final query = box.query((tLong < 100) as Condition).build();
    final propSum = (qp) {
      final p = query.integerProperty(qp);
      try {
        return p.sum();
      }finally {
        p.close();
      }
    };

    final all = box.getAll();

    final add = (a, b) => a + b;

    final sumShort = all.map((s) => s.tShort).toList().fold(0, add);
    final sumInt = all.map((s) => s.tInt).toList().fold(0, add);
    final sumLong = all.map((s) => s.tLong).toList().fold(0, add);

    expect(propSum(tShort), sumShort);
    expect(propSum(tInt), sumInt);
    expect(propSum(tLong), sumLong);

    query.close();
  });

  test(".min", () {
    box.putMany(integerList);

    final query = box.query((tLong < 100) as Condition).build();
    final propMin = (qp) {
      final p = query.integerProperty(qp);
      try {
        return p.min();
      }finally {
        p.close();
      }
    };

    final all = box.getAll();

    final min = (a,b) => a < b ? a : b;

    final minShort = all.map((s) => s.tShort).toList().reduce(min);
    final minInt = all.map((s) => s.tInt).toList().reduce(min);
    final minLong = all.map((s) => s.tLong).toList().reduce(min);

    expect(propMin(tShort), minShort);
    expect(propMin(tInt), minInt);
    expect(propMin(tLong), minLong);

    query.close();
  });

  test(".max", () {
    box.putMany(integerList);

    final query = box.query((tLong < 100) as Condition).build();
    final propMax = (qp) {
      final p = query.integerProperty(qp);
      try {
        return p.max();
      }finally {
        p.close();
      }
    };

    final all = box.getAll();

    final max = (a,b) => a > b ? a : b;

    final maxShort = all.map((s) => s.tShort).toList().reduce(max);
    final maxInt = all.map((s) => s.tInt).toList().reduce(max);
    final maxLong = all.map((s) => s.tLong).toList().reduce(max);

    expect(propMax(tShort), maxShort);
    expect(propMax(tInt), maxInt);
    expect(propMax(tLong), maxLong);

    query.close();
  });

  test(".find", () {
    box.putMany(integerList);

//    final query = box.query(((tLong < 2 | tString.endsWith("suffix")) as Condition) | tDouble.between(0.0, 0.2)) as Condition).build();
    final query = box.query(tLong.lessThan(2).or(tString.endsWith("suffix")).or(tDouble.between(0.0, 0.2))).build();

    tIntegers.forEach((i) {
      final qp = query.property(i) as IntegerPropertyQuery;

      expect(qp.find(), 0); // TODO change
      expect(qp.find(defaultValue:-1), 0); // TODO change

      qp.close();
    });

    tFloats.forEach((f) {
      final qp = query.property(f) as DoublePropertyQuery;

      expect(qp.find(), 0); // TODO change
      expect(qp.find(defaultValue:-0.1), 0); // TODO change

      qp.close();
    });

    final qp = query.property(tString) as StringPropertyQuery;

    expect(qp.find(), ""); // TODO change
    expect(qp..distinct(true) ..caseSensitive(true)..find(), ""); // TODO change
    expect(qp..distinct(false)..caseSensitive(true)..find(defaultValue:"meh"), ""); // TODO change
    expect(qp..distinct(true) ..caseSensitive(false)..find(), ""); // TODO change
    expect(qp..distinct(false)..caseSensitive(false)..find(defaultValue:"meh"), ""); // TODO change
    expect(qp..distinct(true) ..caseSensitive(true)..find(), ""); // TODO change
    expect(qp..distinct(false)..caseSensitive(true)..find(defaultValue:"meh"), ""); // TODO change
    expect(qp..distinct(true) ..caseSensitive(false)..find(), ""); // TODO change
    expect(qp..distinct(false)..caseSensitive(false)..find(defaultValue:"meh"), ""); // TODO change
    qp.close();

    query.close();
  });

  test(".average", () {
    final query = box.query(tDouble.lessThan(1000.0).or(tLong.lessThan(1000))).build();

    // integers
    double intBaseAvg = integers.reduce((a,b) => a + b) / integers.length;

    final qpInteger = (p, avg) {
      final qp = query.integerProperty(p);
      expect(qp.average(), avg);
      qp.close();
    };

    qpInteger(tLong, intBaseAvg + 1); // TODO the avg is 3.0, but the ob avg is 0.0
    qpInteger(tInt, intBaseAvg + 1);
    qpInteger(tShort, intBaseAvg + 1);

    // floats
    final qpFloat = (p, avg) {
      final qp = query.floatProperty(p);
      expect(qp.average(), avg);
      qp.close();
    };

    double floatBaseAvg = floats.reduce((a,b) => a + b) / floats.length;

    qpFloat(tFloat,  floatBaseAvg + 12345);
    qpFloat(tDouble, floatBaseAvg + 12345);

    // close
    query.close();
  });

  tearDown(() {
    env.close();
  });
}

