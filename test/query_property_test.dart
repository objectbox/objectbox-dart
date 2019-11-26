import "package:test/test.dart";
import "package:objectbox/objectbox.dart";
import "entity.dart";
import 'objectbox.g.dart';
import 'test_env.dart';

void main() {
  TestEnv env;
  Box box;

  setUp(() {
    env = TestEnv("query_property");
    box = env.box;
  });

  final integers = [0, 0, 1, 1, 2, 3, 4, 5];
  final integerList = integers.map((i) => TestEntity(tBool:true, tByte:1+i, tShort:2+i, tChar:3+i, tInt:4+i, tLong:5+i)).toList();
  final strings = ["string", "another", "string", "1withSuffix", "2withSuffix", "1withsuffix", "2withsuffix", "swing" ];
  final stringList  = strings.map((s) => TestEntity(tString:s)).toList();
  final floats = [ 0.1, 0.1, 0.1, 0.1, 0.1 ]; // [0, 0.0, 0.1, 0.2, 0.1];
  final floatList  = floats.map((f) => TestEntity(tFloat:0.1+f, tDouble:0.2+f)).toList();

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
    expect(queryString.count(), 7);
    queryString.close();

    final queryBool = box.query(tBool.equals(true)).build();
    expect(queryBool.count(), 8);
    queryBool.close();

    final queryChar = box.query(tChar.greaterThan(0)).build();
    expect(queryChar.count(), 8);
    queryChar.close();
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
    box.putMany(floatList);
    box.putMany(stringList);

//    final query = box.query(((tLong < 2 | tString.endsWith("suffix")) as Condition) | tDouble.between(0.0, 0.2)) as Condition).build();
    final queryIntegers = box.query(tLong.lessThan(100)).build();
    final queryFloats   = box.query(tDouble.between(-1.0, 1.0)).build();
    final queryStrings  = box.query(tString.endsWith("suffix")).build();

    final start = [ 2, 4, 5 ];
    for (int i=0; i<tIntegers.length; i++) {
      final qp = queryIntegers.property(tIntegers[i]) as IntegerPropertyQuery;

      final mappedIntegers = integers.map((j) => j + start[i]).toList();
      expect(qp.find(defaultValue:-1), mappedIntegers);
      expect(qp.find(), mappedIntegers);

      qp.close();
    }

    tFloats.forEach((f) {
      final qp = queryFloats.property(f) as DoublePropertyQuery;

      double d = tFloat == f ? 0.20000000298023224 : 0.30000000000000004;

      expect(qp.find(), [ d, d, d, d, d ]);
      expect(qp.find(defaultValue:-0.1), [ d, d, d, d, d ]);

      qp.close();
    });

    final qp = queryStrings.property(tString) as StringPropertyQuery;

    final defaultResult = ['1withSuffix', '2withSuffix', '1withsuffix', '2withsuffix'];
    expect(qp.find(), defaultResult);
    expect((qp..distinct = true ..caseSensitive = true) .find(), ['2withsuffix', '1withsuffix', '2withSuffix', '1withSuffix'] );
    expect((qp..distinct = false..caseSensitive = true) .find(defaultValue:"meh"), ['1withSuffix', '2withSuffix', '1withsuffix', '2withsuffix']);
    expect((qp..distinct = true ..caseSensitive = false).find(), ['2withSuffix', '1withSuffix']);
    expect((qp..distinct = false..caseSensitive = false).find(defaultValue:"meh"), defaultResult);
    qp.close();

    queryIntegers.close();
    queryFloats.close();
    queryStrings.close();
  });

  test(".average", () {
    box.putMany(integerList);
    box.putMany(floatList);

    final queryIntegers = box.query(tLong.lessThan(1000)).build();
    final queryFloats   = box.query(tDouble.lessThan(1000.0)).build();

    // integers
    double intBaseAvg = integers.reduce((a,b) => a + b) / integers.length;

    final qpInteger = (p, avg) {
      final qp = queryIntegers.integerProperty(p);
      expect(qp.average(), avg);
      qp.close();
    };

    qpInteger(tLong, intBaseAvg + 5);
    qpInteger(tInt, intBaseAvg + 4);
    qpInteger(tShort, intBaseAvg + 2);

    // floats
    final qpFloat = (p, avg) {
      final qp = queryFloats.doubleProperty(p);
      expect(qp.average(), avg);
      qp.close();
    };

    double floatBaseAvg = floats.reduce((a,b) => a + b) / floats.length;

    qpFloat(tFloat,  floatBaseAvg + 0.10000000298023224);
    qpFloat(tDouble, 0.30000000000000004);

    // close
    queryFloats.close();
    queryIntegers.close();
  });

  test(".find() default values on null results" , () {
    box.putMany(integerList);
    box.putMany(stringList);
    box.putMany(floatList);

    final queryIntegers = box.query(tLong.greaterThan(1000)).build();
    final queryFloats   = box.query(tDouble.greaterThan(1000.0)).build();
    final queryStrings  = box.query(tString.equals("can't find this")).build();

    final integerDefaultValue = -2;

    final qpInteger = (p, dv) {
      final qp = queryIntegers.integerProperty(p);
      expect(qp.find(defaultValue: -2), dv);
      qp.close();
    };

    tIntegers.forEach((i) {
      qpInteger(i, integerDefaultValue);
    });

    // floats
    final floatDefaultValue = -1337.0;

    final qpFloat = (p, dv) {
      final qp = queryFloats.doubleProperty(p);
      expect(qp.find(defaultValue: -1337.0), dv);
      qp.close();
    };

    qpFloat(tFloat, floatDefaultValue);
    qpFloat(tDouble, floatDefaultValue);

  });

  test(".distinct, .count, .close property query", () {
    box.putMany(integerList);
    box.putMany(stringList);
    box.putMany(floatList);

    // int
    tIntegers.forEach((t) {
      final query = box.query(t.lessThan(100)).build();
      final queryInt = query.property(t);
      expect(queryInt.count(), 4); // TODO replace
      expect((queryInt..distinct = true).count(), 4); // TODO replace
      queryInt.close();
      query.close();
    });

    // floats
    tFloats.forEach((t) {
      final query = box.query(t.lessThan(100.0)).build();
      final queryFloat = query.property(t);
      expect(queryFloat.count(), 4); // TODO replace
      expect((queryFloat..distinct = true).count(), 4); // TODO replace
      queryFloat.close();
      query.close();
    });

    // string
    final query = box.query(tString.contains("t")).build();
    final queryString = query.property(tString);
    expect(queryString.count(), 4); // TODO replace
    expect((queryString..distinct = true).count(), 4); // TODO replace
    queryString.close();
    query.close();

  });

  // TODO write tests for byte and char

  tearDown(() {
    env.close();
  });
}

