import 'dart:math';

import 'package:objectbox/internal.dart';
import 'package:objectbox/objectbox.dart';
import 'package:test/test.dart';

import 'entity.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

void main() {
  late TestEnv env;
  late Box<TestEntity> box;

  setUp(() {
    env = TestEnv('query_property');
    box = env.box;
  });

  tearDown(() => env.close());

  final integers = [-6, 0, 0, 1, 1, 2, 3, 4, 5];
  final integerList = () => integers
      .map((i) => TestEntity(
          tBool: true,
          tByte: 1 + i,
          tShort: 2 + i,
          tChar: 3 + i,
          tInt: 4 + i,
          tLong: 5 + i))
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
  final stringList = () => strings.map((s) => TestEntity(tString: s)).toList();
  final floats = [-0.5, 0, 0.0, 0.1, 0.2, 0.1];
  final floatList = () =>
      floats.map((f) => TestEntity(tFloat: 0.1 + f, tDouble: 0.2 + f)).toList();

  final tBool = TestEntity_.tBool;
  final tChar = TestEntity_.tChar;
  final tByte = TestEntity_.tByte;

  final tLong = TestEntity_.tLong;
  final tInt = TestEntity_.tInt;
  final tShort = TestEntity_.tShort;

  // OB prohibits aggregate operations on tBool & tChar
  final tIntegers = [
    /*tBool, tChar,*/
    tByte,
    tShort,
    tInt,
    tLong
  ]; // starts resp. 1, 2, 4, 5

  final tFloat = TestEntity_.tFloat;
  final tDouble = TestEntity_.tDouble;
  final tFloats = [tFloat, tDouble];

  final tString = TestEntity_.tString;

  test('.count (basic query)', () {
    box.putMany(integerList());
    box.putMany(stringList());
    box.putMany(floatList());

    tIntegers.forEach((i) {
      final queryInt = box.query(i.greaterThan(0)).build();
      expect(queryInt.count(), 8);
      queryInt.close();
    });

    tFloats.forEach((f) {
      final queryFloat = box.query(f.lessThan(1.0)).build();
      expect(queryFloat.count(), 6);
      queryFloat.close();
    });

    final queryString =
        box.query(tString.contains('t', caseSensitive: false)).build();
    expect(queryString.count(), 8);
    queryString.close();

    final queryBool = box.query(tBool.equals(true)).build();
    expect(queryBool.count(), 9);
    queryBool.close();

    final queryChar = box.query(tChar.greaterThan(0)).build();
    expect(queryChar.count(), 8);
    queryChar.close();
  });

  test('query.property(E_.field) property query, type inference', () {
    box.putMany(integerList());
    box.putMany(stringList());
    box.putMany(floatList());

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

    query.close();
  });

  test('.sum integers', () {
    box.putMany(integerList());

    final query = box.query((tLong < 100)).build();
    final all = box.getAll();

    final sumByte = all.map((s) => s.tByte!).toList().fold(0, _add);
    final sumShort = all.map((s) => s.tShort!).toList().fold(0, _add);
    final sumInt = all.map((s) => s.tInt!).toList().fold(0, _add);
    final sumLong = all.map((s) => s.tLong!).toList().fold(0, _add);

    expect(_propQueryExecInt(query, tByte, _pqSumInt), sumByte);
    expect(_propQueryExecInt(query, tShort, _pqSumInt), sumShort);
    expect(_propQueryExecInt(query, tInt, _pqSumInt), sumInt);
    expect(_propQueryExecInt(query, tLong, _pqSumInt), sumLong);

    query.close();
  });

  test('.min integers', () {
    box.putMany(integerList());

    final query = box.query((tLong < 100)).build();
    final all = box.getAll();

    final minByte = all.map((s) => s.tByte!).toList().reduce(min);
    final minShort = all.map((s) => s.tShort!).toList().reduce(min);
    final minInt = all.map((s) => s.tInt!).toList().reduce(min);
    final minLong = all.map((s) => s.tLong!).toList().reduce(min);

    expect(_propQueryExecInt(query, tByte, _pqMinInt), minByte);
    expect(_propQueryExecInt(query, tShort, _pqMinInt), minShort);
    expect(_propQueryExecInt(query, tInt, _pqMinInt), minInt);
    expect(_propQueryExecInt(query, tLong, _pqMinInt), minLong);

    query.close();
  });

  test('.max integers', () {
    box.putMany(integerList());

    final query = box.query((tLong < 100)).build();
    final all = box.getAll();

    final maxByte = all.map((s) => s.tByte!).toList().reduce(max);
    final maxShort = all.map((s) => s.tShort!).toList().reduce(max);
    final maxInt = all.map((s) => s.tInt!).toList().reduce(max);
    final maxLong = all.map((s) => s.tLong!).toList().reduce(max);

    expect(_propQueryExecInt(query, tByte, _pqMaxInt), maxByte);
    expect(_propQueryExecInt(query, tShort, _pqMaxInt), maxShort);
    expect(_propQueryExecInt(query, tInt, _pqMaxInt), maxInt);
    expect(_propQueryExecInt(query, tLong, _pqMaxInt), maxLong);

    query.close();
  });

  test('.sum floats', () {
    box.putMany(floatList());

    final query = box.query((tFloat > -10.0).or(tDouble > -10.0)).build();

    final all = box.getAll();

    final sumFloat = all.map((s) => s.tFloat!).toList().fold(0.0, _add);
    final sumDouble = all.map((s) => s.tDouble!).toList().fold(0.0, _add);

    expect(_propQueryExecDouble(query, tFloat, _pqSumDouble), sumFloat);
    expect(_propQueryExecDouble(query, tDouble, _pqSumDouble), sumDouble);

    query.close();
  });

  test('.min floats', () {
    box.putMany(floatList());

    final query = box.query((tFloat > -10.0).or(tDouble > -10.0)).build();

    final all = box.getAll();

    final minFloat = all.map((s) => s.tFloat!).toList().reduce(min);
    final minDouble = all.map((s) => s.tDouble!).toList().reduce(min);

    expect(_propQueryExecDouble(query, tFloat, _pqMinDouble), minFloat);
    expect(_propQueryExecDouble(query, tDouble, _pqMinDouble), minDouble);

    query.close();
  });

  test('.max floats', () {
    box.putMany(floatList());

    final query = box.query((tFloat > -10.0).or(tDouble > -10.0)).build();
    final all = box.getAll();

    final maxFloat = all.map((s) => s.tFloat!).toList().reduce(max);
    final maxDouble = all.map((s) => s.tDouble!).toList().reduce(max);

    expect(_propQueryExecDouble(query, tFloat, _pqMaxDouble), maxFloat);
    expect(_propQueryExecDouble(query, tDouble, _pqMaxDouble), maxDouble);

    query.close();
  });

  test('.find', () {
    box.putMany(integerList());
    box.putMany(floatList());
    box.putMany(stringList());

    final queryIntegers = box.query(tLong.lessThan(100)).build();
    final queryFloats = box.query(tDouble.between(-1.0, 1.0)).build();
    final queryStrings =
        box.query(tString.endsWith('suffix', caseSensitive: false)).build();

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
      final expected =
          floats.map((f) => (f + increment).toStringAsFixed(2)).toList();

      expect(qp.find().map((f) => f.toStringAsFixed(2)).toList(), expected);

      qp.close();
    });

    final stringQuery = queryStrings.property(tString) as StringPropertyQuery;

    // Note: results are in no particular order, so sort them before comparing.
    final defaultResults = [
      '1withSuffix',
      '1withSuffix',
      '2WITHSUFFIX',
      '2withSuffix',
      '2withSuffix'
    ];
    var results = stringQuery.find()..sort();
    expect(results, defaultResults);

    var resultsNone = (stringQuery
          ..distinct = false
          ..caseSensitive = false)
        .find(replaceNullWith: 'meh')
          ..sort();
    expect(resultsNone, defaultResults);

    var resultsDC = (stringQuery
          ..distinct = true
          ..caseSensitive = true)
        .find()
          ..sort();
    expect(resultsDC, ['1withSuffix', '2WITHSUFFIX', '2withSuffix']);

    var resultsC = (stringQuery
          ..distinct = false
          ..caseSensitive = true)
        .find(replaceNullWith: 'meh')
          ..sort();
    expect(resultsC, defaultResults);

    var resultsD = (stringQuery
          ..distinct = true
          ..caseSensitive = false)
        .find()
          ..sort();
    expect(resultsD, ['1withSuffix', '2withSuffix']);

    stringQuery.close();

    queryIntegers.close();
    queryFloats.close();
    queryStrings.close();
  });

  test('.average', () {
    box.putMany(integerList());
    box.putMany(floatList());

    final queryIntegers = box.query(tLong.lessThan(1000)).build();
    final queryFloats = box.query(tDouble.lessThan(1000.0)).build();

    // integers
    var intBaseAvg = integers.reduce((a, b) => a + b) / integers.length;

    final qpInteger = (QueryProperty p, double avg) {
      final qp = queryIntegers.integerProperty(p);
      expect(qp.average(), avg);
      qp.close();
    };

    qpInteger(tByte, intBaseAvg + 1);
    qpInteger(tLong, intBaseAvg + 5);
    qpInteger(tInt, intBaseAvg + 4);
    qpInteger(tShort, intBaseAvg + 2);

    // floats
    final qpFloat = (QueryProperty p, double avg) {
      final qp = queryFloats.doubleProperty(p);
      expect(qp.average().toStringAsFixed(2), avg.toStringAsFixed(2));
      qp.close();
    };

    var floatBaseAvg = floats.reduce((a, b) => a + b) / floats.length;

    qpFloat(tFloat, floatBaseAvg + 0.1);
    qpFloat(tDouble, floatBaseAvg + 0.2);

    // close
    queryFloats.close();
    queryIntegers.close();
  });

  test('.find() replace null integers', () {
    // integers are null on string populated entities
    box.putMany(stringList());

    final queryStrings = box.query(tString.contains('t')).build();
    final queryAndCheck = (QueryProperty prop, int valueIfNull, String reason) {
      final qp = queryStrings.integerProperty(prop);
      expect(qp.find(replaceNullWith: valueIfNull).first, valueIfNull,
          reason: reason);
      qp.close();
    };
    queryAndCheck(tByte, 3, 'byte null->positive');
    queryAndCheck(tShort, 3, 'short null->positive');
    queryAndCheck(tInt, 3, 'int null->positive');
    queryAndCheck(tLong, 3, 'long null->positive');

    queryAndCheck(tByte, -2, 'byte null->negative');
    queryAndCheck(tShort, -2, 'short null->negative');
    queryAndCheck(tInt, -2, 'int null->negative');
    queryAndCheck(tLong, -2, 'long null->negative');

    queryStrings.close();
  });

  test('.find() replace null floats', () {
    // floats are null on integer populated entities
    box.putMany(integerList());

    final queryIntegers = box.query(tLong.lessThan(1000)).build();
    final queryAndCheck =
        (QueryProperty prop, double valueIfNull, String reason) {
      final qp = queryIntegers.doubleProperty(prop);
      expect(qp.find(replaceNullWith: valueIfNull).first, valueIfNull,
          reason: reason);
      qp.close();
    };

    queryAndCheck(tDouble, 1337.0, 'null double');
    queryAndCheck(tFloat, 1337.0, 'null float');

    queryIntegers.close();
  });

  test('.find() replace null strings', () {
    // strings are null on float populated entities
    box.putMany(floatList());

    final queryFloats = box.query(tDouble.lessThan(1000.0)).build();
    final qp = queryFloats.stringProperty(tString);
    expect(qp.find(replaceNullWith: 't').first, 't');
    qp.close();
    queryFloats.close();
  });

  test('.distinct, .count, .close property query', () {
    box.putMany(integerList());
    box.putMany(stringList());
    box.putMany(floatList());

    // int
    for (var i = 0; i < tIntegers.length; i++) {
      final query = box.query(tIntegers[i].lessThan(100)).build();
      final queryInt = query.property(tIntegers[i]);

      expect(queryInt.count(), 9);
      expect((queryInt..distinct = true).count(), 7);
      queryInt.close();
      query.close();
    }

    // floats
    for (var i = 0; i < tFloats.length; i++) {
      final query = box.query(tFloats[i].lessThan(100.0)).build();
      final queryFloat = query.property(tFloats[i]);
      expect(queryFloat.count(), 6);
      expect((queryFloat..distinct = true).count(), 4);
      queryFloat.close();
      query.close();
    }

    // string
    final query =
        box.query(tString.contains('t', caseSensitive: false)).build();
    final queryString = query.property(tString) as StringPropertyQuery;
    expect(queryString.count(), 8);
    expect((queryString..distinct = true).count(), 5);
    expect(
        (queryString
              ..distinct = false
              ..caseSensitive = false)
            .count(),
        8);
    expect(
        (queryString
              ..distinct = false
              ..caseSensitive = true)
            .count(),
        8);
    expect(
        (queryString
              ..distinct = true
              ..caseSensitive = false)
            .count(),
        5);
    expect(
        (queryString
              ..distinct = true
              ..caseSensitive = true)
            .count(),
        5);
    queryString.close();
    query.close();
  });
}

T _add<T extends num>(T lhs, T rhs) => (lhs + rhs) as T;

T _propQueryExecInt<T>(Query query, QueryProperty prop,
    T Function(IntegerPropertyQuery propQuery) fn) {
  final propQuery = query.integerProperty(prop);
  try {
    return fn(propQuery);
  } finally {
    propQuery.close();
  }
}

int _pqSumInt(IntegerPropertyQuery propQuery) => propQuery.sum();

int _pqMinInt(IntegerPropertyQuery propQuery) => propQuery.min();

int _pqMaxInt(IntegerPropertyQuery propQuery) => propQuery.max();

T _propQueryExecDouble<T>(Query query, QueryProperty prop,
    T Function(DoublePropertyQuery propQuery) fn) {
  final propQuery = query.doubleProperty(prop);
  try {
    return fn(propQuery);
  } finally {
    propQuery.close();
  }
}

double _pqSumDouble(DoublePropertyQuery propQuery) => propQuery.sum();

double _pqMinDouble(DoublePropertyQuery propQuery) => propQuery.min();

double _pqMaxDouble(DoublePropertyQuery propQuery) => propQuery.max();
