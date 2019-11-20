import "package:test/test.dart";
import "package:objectbox/objectbox.dart";
import "entity.dart";
import 'test_env.dart';

void main() {
  TestEnv<TestEntity> env;
  Box box;

  setUp(() {
    env = TestEnv(TestEntity_OBXDefs, "query_property");
    box = env.box;
  });

  final integers = [0, 0, 1, 1, 2, 3, 4, 5];
  final integerList = integers.map((i) => TestEntity(tBool:true, tByte:1+i, tShort:2+i, tChar:3+i, tInt:4+i, tLong:5+i)).toList();
  final strings = ["string", "another", "string", "1withSuffix", "2withSuffix", "1withSuffix"];
  final stringList  = strings.map((s) => TestEntity(tString:s)).toList();
  final floats = [ 0.1, 0.1, 0.1, 0.1, 0.1 ]; // [0, 0.0, 0.1, 0.2, 0.1];
  final floatList  = floats.map((f) => TestEntity(tFloat:0.1+f, tDouble:0.1+f)).toList();

  final tBool = TestEntity_.tBool;
  final tChar = TestEntity_.tChar;
  final tByte = TestEntity_.tByte;

  final tLong = TestEntity_.tLong;
  final tInt = TestEntity_.tInt;
  final tShort = TestEntity_.tShort;
  final tIntegers = [ tShort, tInt, tLong ]; // starts resp. 2, 4, 5

  final tFloat = TestEntity_.tFloat;
  final tDouble = TestEntity_.tDouble;
  final tFloats = [ tFloat, tDouble ];

  final tString = TestEntity_.tString;

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
    final query = box.query((tLong < 100) as Condition).build();

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

  final add = (a, b) => a + b;
  test(".sum integers", () {
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

    final sumShort = all.map((s) => s.tShort).toList().fold(0, add);
    final sumInt = all.map((s) => s.tInt).toList().fold(0, add);
    final sumLong = all.map((s) => s.tLong).toList().fold(0, add);

    expect(propSum(tShort), sumShort);
    expect(propSum(tInt), sumInt);
    expect(propSum(tLong), sumLong);

    query.close();
  });

  final min = (a,b) => a < b ? a : b;
  test(".min integers", () {
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

    final minShort = all.map((s) => s.tShort).toList().reduce(min);
    final minInt = all.map((s) => s.tInt).toList().reduce(min);
    final minLong = all.map((s) => s.tLong).toList().reduce(min);

    expect(propMin(tShort), minShort);
    expect(propMin(tInt), minInt);
    expect(propMin(tLong), minLong);

    query.close();
  });

  final max = (a,b) => a > b ? a : b;
  test(".max integers", () {
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

    final maxShort = all.map((s) => s.tShort).toList().reduce(max);
    final maxInt = all.map((s) => s.tInt).toList().reduce(max);
    final maxLong = all.map((s) => s.tLong).toList().reduce(max);

    expect(propMax(tShort), maxShort);
    expect(propMax(tInt), maxInt);
    expect(propMax(tLong), maxLong);

    query.close();
  });

  test(".sum floats", () {
    box.putMany(floatList);

    final query = box.query((tFloat > -0.01).or(tDouble > -0.01) as Condition).build();
    final propSum = (qp) {
      final p = query.doubleProperty(qp);
      try {
        return p.sum();
      }finally {
        p.close();
      }
    };

    final all = box.getAll();

    final sumFloat = all.map((s) => s.tFloat).toList().fold(0, add);
    final sumDouble = all.map((s) => s.tDouble).toList().fold(0, add);

    expect(propSum(tFloat), sumFloat);
    expect(propSum(tDouble), sumDouble);

    query.close();
  });

  test(".min floats", () {
    box.putMany(floatList);

    final query = box.query((tFloat > -0.01).or(tDouble > -0.01) as Condition).build();
    final propMin = (qp) {
      final p = query.doubleProperty(qp);
      try {
        return p.min();
      }finally {
        p.close();
      }
    };

    final all = box.getAll();

    final minFloat = all.map((s) => s.tFloat).toList().reduce(min);
    final minDouble = all.map((s) => s.tDouble).toList().reduce(min);

    expect(propMin(tFloat), minFloat);
    expect(propMin(tDouble), minDouble);

    query.close();
  });

  test(".max floats", () {
    box.putMany(floatList);

    final query = box.query((tFloat > -0.01).or(tDouble > -0.01) as Condition).build();
    final propMax = (qp) {
      final p = query.doubleProperty(qp);
      try {
        return p.max();
      }finally {
        p.close();
      }
    };

    final all = box.getAll();

    final maxFloat = all.map((s) => s.tFloat).toList().reduce(max);
    final maxDouble = all.map((s) => s.tDouble).toList().reduce(max);

    expect(propMax(tFloat), maxFloat);
    expect(propMax(tDouble), maxDouble);

    query.close();
  });

  test(".find", () {
    box.putMany(integerList);

//    final query = box.query(((tLong < 2 | tString.endsWith("suffix")) as Condition) | tDouble.between(0.0, 0.2)) as Condition).build();
    final query = box.query(tLong.lessThan(100).or(tString.endsWith("suffix")).or(tDouble.between(-100000.0, 100000.0))).build();

    final start = [ 2, 4, 5 ];
    for (int i=0; i<tIntegers.length; i++) {
      final qp = query.property(tIntegers[i]) as IntegerPropertyQuery;

      final mappedIntegers = integers.map((j) => j + start[i]).toList();
      expect(qp.find(defaultValue:-1), mappedIntegers);
      expect(qp.find(), mappedIntegers);

      qp.close();
    }

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
      final qp = query.doubleProperty(p);
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

