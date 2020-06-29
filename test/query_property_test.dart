import 'package:objectbox/objectbox.dart';
import 'package:test/test.dart';

import 'entity.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

void main() {
  TestEnv env;
  Box box;

  setUp(() {
    env = TestEnv('query_property');
    box = env.box;
  });

  final integers = [0, 0, 1, 1, 2, 3, 4, 5];
  final integerList = integers
      .map((i) => TestEntity(tBool: true, tChar: 3 + i, tByte: 1 + i, tShort: 2 + i, tInt: 4 + i, tLong: 5 + i))
      .toList();
  final strings = [
    'string',
    'another',
    'string',
    '1withSuffix',
    '2withSuffix',
    '1withSuffix',
    '2withSuffix',
    'swing',
    '2WITHSUFFIX'
  ];
  final stringList = strings.map((s) => TestEntity(tString: s)).toList();
  final floats = [0, 0.0, 0.1, 0.2, 0.1];
  final floatList = floats.map((f) => TestEntity(tFloat: 0.1 + f, tDouble: 0.2 + f)).toList();

  final tBool = TestEntity_.tBool;
  final tChar = TestEntity_.tChar;
  final tByte = TestEntity_.tByte;

  final tLong = TestEntity_.tLong;
  final tInt = TestEntity_.tInt;
  final tShort = TestEntity_.tShort;

  // OB prohibits aggregate operations on tBool & tChar
  final tIntegers = [/*tBool, tChar,*/ tByte, tShort, tInt, tLong]; // starts resp. 1, 2, 4, 5

  final tFloat = TestEntity_.tFloat;
  final tDouble = TestEntity_.tDouble;
  final tFloats = [tFloat, tDouble];

  final tString = TestEntity_.tString;

  test('.count (basic query)', () {
    box.putMany(integerList);
    box.putMany(stringList);
    box.putMany(floatList);

    tIntegers.forEach((i) {
      final queryInt = box.query(i.greaterThan(0)).build();
      expect(queryInt.count(), 8);
      queryInt.close();
    });

    tFloats.forEach((f) {
      final queryFloat = box.query(f.lessThan(1.0)).build();
      expect(queryFloat.count(), 5);
      queryFloat.close();
    });

    final queryString = box.query(tString.contains('t')).build();
    expect(queryString.count(), 8);
    queryString.close();

    final queryBool = box.query(tBool.equals(true)).build();
    expect(queryBool.count(), 8);
    queryBool.close();

    final queryChar = box.query(tChar.greaterThan(0)).build();
    expect(queryChar.count(), 8);
    queryChar.close();
  });

  test('query.property(E_.field) property query, type inference', () {
    box.putMany(integerList);
    box.putMany(stringList);
    box.putMany(floatList);

    final query = box.query(tLong < 2).build();

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
  test('.sum integers', () {
    box.putMany(integerList);

    final query = box.query((tLong < 100)).build();
    final propSum = (qp) {
      final p = query.integerProperty(qp);
      try {
        return p.sum();
      } finally {
        p.close();
      }
    };

    final all = box.getAll();

    final sumShort = all.map((s) => s.tShort).toList().fold(0, add);
    final sumInt = all.map((s) => s.tInt).toList().fold(0, add);
    final sumLong = all.map((s) => s.tLong).toList().fold(0, add);
//    final sumChar = all.map((s) => s.tChar).toList().fold(0, add);
    final sumByte = all.map((s) => s.tByte).toList().fold(0, add);

    expect(propSum(tShort), sumShort);
    expect(propSum(tInt), sumInt);
    expect(propSum(tLong), sumLong);

    expect(propSum(tByte), sumByte);
//    expect(propSum(tChar), sumChar); // ObjectBoxException: 10002 Property does not allow sum: tChar

    query.close();
  });

  final min = (a, b) => a < b ? a : b;
  test('.min integers', () {
    box.putMany(integerList);

    final query = box.query((tLong < 100)).build();
    final propMin = (qp) {
      final p = query.integerProperty(qp);
      try {
        return p.min();
      } finally {
        p.close();
      }
    };

    final all = box.getAll();

    final minShort = all.map((s) => s.tShort).toList().reduce(min);
    final minInt = all.map((s) => s.tInt).toList().reduce(min);
    final minLong = all.map((s) => s.tLong).toList().reduce(min);

    final minByte = all.map((s) => s.tByte).toList().reduce(min);
//    final minChar = all.map((s) => s.tChar).toList().reduce(min);

    expect(propMin(tShort), minShort);
    expect(propMin(tInt), minInt);
    expect(propMin(tLong), minLong);

    expect(propMin(tByte), minByte);
//    expect(propMin(tChar), minChar); // ObjectBoxException: 10002 Property does not allow max: tChar

    query.close();
  });

  final max = (a, b) => a > b ? a : b;
  test('.max integers', () {
    box.putMany(integerList);

    final query = box.query((tLong < 100)).build();
    final propMax = (qp) {
      final p = query.integerProperty(qp);
      try {
        return p.max();
      } finally {
        p.close();
      }
    };

    final all = box.getAll();

    final maxShort = all.map((s) => s.tShort).toList().reduce(max);
    final maxInt = all.map((s) => s.tInt).toList().reduce(max);
    final maxLong = all.map((s) => s.tLong).toList().reduce(max);
    final maxByte = all.map((s) => s.tByte).toList().reduce(max);

    expect(propMax(tShort), maxShort);
    expect(propMax(tInt), maxInt);
    expect(propMax(tLong), maxLong);

    expect(propMax(tByte), maxByte);

    query.close();
  });

  test('.sum floats', () {
    box.putMany(floatList);

    final query = box.query((tFloat > -0.01).or(tDouble > -0.01)).build();
    final propSum = (qp) {
      final p = query.doubleProperty(qp);
      try {
        return p.sum();
      } finally {
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

  test('.min floats', () {
    box.putMany(floatList);

    final query = box.query((tFloat > -0.01).or(tDouble > -0.01)).build();
    final propMin = (qp) {
      final p = query.doubleProperty(qp);
      try {
        return p.min();
      } finally {
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

  test('.max floats', () {
    box.putMany(floatList);

    final query = box.query((tFloat > -0.01).or(tDouble > -0.01)).build();
    final propMax = (qp) {
      final p = query.doubleProperty(qp);
      try {
        return p.max();
      } finally {
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

  test('.find', () {
    box.putMany(integerList);
    box.putMany(floatList);
    box.putMany(stringList);

//    final query = box.query(((tLong < 2 | tString.endsWith('suffix')) as Condition) | tDouble.between(0.0, 0.2)) as Condition).build();
    final queryIntegers = box.query(tLong.lessThan(100)).build();
    final queryFloats = box.query(tDouble.between(-1.0, 1.0)).build();
    final queryStrings = box.query(tString.endsWith('suffix')).build();

    final start = [1, 2, 4, 5];
    for (var i = 0; i < tIntegers.length; i++) {
      final qp = queryIntegers.property(tIntegers[i]) as IntegerPropertyQuery;

      final mappedIntegers = integers.map((j) => j + start[i]).toList();
      expect(qp.find(replaceNullWith: -1), mappedIntegers);
      expect(qp.find(), mappedIntegers);

      qp.close();
    }

    tFloats.forEach((f) {
      final qp = queryFloats.property(f) as DoublePropertyQuery;

      final increment = tFloat == f ? 0.1 : 0.2;
      final expected = floats.map((f) => (f + increment).toStringAsFixed(2)).toList();

      expect(qp.find().map((f) => f.toStringAsFixed(2)).toList(), expected);

      qp.close();
    });

    final qp = queryStrings.property(tString) as StringPropertyQuery;

    List<String> addSuffix(List<int> s) {
      return s.map((t) => '${t}withSuffix').toList();
    }

    final caps = ['2WITHSUFFIX'];
    final defaultResult = addSuffix([1, 2, 1, 2]) + caps;
    expect(qp.find(), defaultResult);
    expect((qp..distinct = true ..caseSensitive = true) .find(), caps + addSuffix([2,1]) );
    expect((qp..distinct = false..caseSensitive = true) .find(replaceNullWith:'meh'), addSuffix([1,2,1,2]) + caps);
    expect((qp..distinct = true ..caseSensitive = false).find(), addSuffix([2,1]));
    expect((qp..distinct = false..caseSensitive = false).find(replaceNullWith:'meh'), defaultResult);
    qp.close();

    queryIntegers.close();
    queryFloats.close();
    queryStrings.close();
  });

  test('.average', () {
    box.putMany(integerList);
    box.putMany(floatList);

    final queryIntegers = box.query(tLong.lessThan(1000)).build();
    final queryFloats = box.query(tDouble.lessThan(1000.0)).build();

    // integers
    var intBaseAvg = integers.reduce((a, b) => a + b) / integers.length;

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
      expect(qp.average().toStringAsFixed(2), avg.toString());
      qp.close();
    };

    var floatBaseAvg = floats.reduce((a, b) => a + b) / floats.length;

    qpFloat(tFloat, floatBaseAvg + 0.1);
    qpFloat(tDouble, floatBaseAvg + 0.2);

    // char, byte
//    qpInteger(tChar, intBaseAvg); // ObjectBoxException: 10002 Property does not allow avg: tChar
    qpInteger(tByte, intBaseAvg + 1);

    // close
    queryFloats.close();
    queryIntegers.close();
  });

  test('.find() replace null result with some value', () {
    box.putMany(integerList);
    box.putMany(stringList);
    box.putMany(floatList);

    final queryIntegers = box.query(tLong.lessThan(1000)).build();
    final queryFloats = box.query(tDouble.lessThan(1000.0)).build();
    final queryStrings = box.query(tString.contains('t')).build();

    // find integers on string populated entities
    final integerValues = [3, 3, 3, 3, 3, 3, 3, 3];

    // ObjectBoxException: find int8: 10203 Property 'tChar' is of type Char, but we expected a property of type Byte in this context
    final qpInteger = (p, dv) {
      final qp = queryStrings.integerProperty(p);
      expect(qp.find(replaceNullWith: 3), dv);
      qp.close();
    };

    tIntegers.forEach((i) {
      qpInteger(i, integerValues);
    });

    /// Only unsigned 'replaceWithNull' values are allowed for
    /// tShort and tInteger. Is this an architecture, dart or OB bug/feature/issue?
    final negIntegerValues = [-2, -2, -2, -2, -2, -2, -2, -2];

    final qpNegInteger = (p, dv) {
      final qp = queryStrings.integerProperty(p);
      expect(qp.find(replaceNullWith: -2), dv);
      qp.close();
    };

    qpNegInteger(tLong, negIntegerValues);

    // find floats on integer populated entities
    final floatValues = [1337.0, 1337.0, 1337.0, 1337.0, 1337.0, 1337.0, 1337.0, 1337.0];

    final qpFloat = (p, dv) {
      final qp = queryIntegers.doubleProperty(p);
      expect(qp.find(replaceNullWith: 1337.0), dv);
      qp.close();
    };

    qpFloat(tDouble, floatValues);

    /// Evidently, tFloat is never null, it's always initialized to 0.0,
    /// so, 'replaceWithNull' is useless here.
    /// Is this an architecture, dart or OB bug/feature/issue?
//    qpFloat(tFloat, floatValues);

    // find strings on float populated entities
    final stringValues = ['t', 't', 't', 't', 't'];
    final qp = queryFloats.stringProperty(tString);
    expect(qp.find(replaceNullWith: 't'), stringValues);
    qp.close();
  });

  test('.distinct, .count, .close property query', () {
    box.putMany(integerList);
    box.putMany(stringList);
    box.putMany(floatList);

    final expectedIntegers = [8, 8, 8, 8];
    final expectedDistinctIntegers = [6, 6, 6, 6];

    // int
    for (var i = 0; i < tIntegers.length; i++) {
      final query = box.query(tIntegers[i].lessThan(100)).build();
      final queryInt = query.property(tIntegers[i]);

      expect(queryInt.count(), expectedIntegers[i]);
      expect((queryInt..distinct = true).count(), expectedDistinctIntegers[i]);
      queryInt.close();
      query.close();
    }

    // floats
    for (var i = 0; i < tFloats.length; i++) {
      final query = box.query(tFloats[i].lessThan(100.0)).build();
      final queryFloat = query.property(tFloats[i]);
      expect(queryFloat.count(), 5);
      expect((queryFloat..distinct = true).count(), 3);
      queryFloat.close();
      query.close();
    }

    // string
    final query = box.query(tString.contains('t')).build();
    final queryString = query.property(tString) as StringPropertyQuery;
    expect(queryString.count(), 8);
    expect((queryString..distinct = true).count(), 5);
    expect((queryString..distinct = false..caseSensitive = false).count(), 8);
    expect((queryString..distinct = false..caseSensitive = true).count(), 8);
    expect((queryString..distinct = true..caseSensitive = false).count(), 5);
    expect((queryString..distinct = true..caseSensitive = true).count(), 5);
    queryString.close();
    query.close();
  });

  tearDown(() {
    env.close();
  });
}
