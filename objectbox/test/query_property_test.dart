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
    'String',
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
  final tSignedInts = [tByte, tShort, tLong]; // values start at 1, 2 & 5
  final tUnsignedInts = [tInt];

  final tFloat = TestEntity_.tFloat;
  final tDouble = TestEntity_.tDouble;
  final tFloats = [tFloat, tDouble];

  final tString = TestEntity_.tString;

  test('property query auto-close', () {
    // Finalizer is executed after the query object goes out of scope.
    // Note: only caught by valgrind - I've tested that it actually catches
    // when the finalizer assignment was disabled. Now, this will only fail in
    // CI when running valgrind.sh - if finalizer won't work properly.
    box.query().build().property(TestEntity_.tString).find();
  });

  test('.count (basic query)', () {
    box.putMany(integerList());
    box.putMany(stringList());
    box.putMany(floatList());

    tSignedInts.forEach((i) {
      final queryInt = box.query(i.greaterThan(0)).build();
      expect(queryInt.count(), 8);
      queryInt.close();
    });

    tUnsignedInts.forEach((i) {
      final queryInt = box.query(i.greaterThan(0)).build();
      expect(queryInt.count(), 9);
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

    tSignedInts.forEach((prop) {
      final qp = query.property(prop);
      expect(qp is PropertyQuery<int>, true);
      qp.close();
    });

    tFloats.forEach((prop) {
      final qp = query.property(prop);
      expect(qp is PropertyQuery<double>, true);
      qp.close();
    });

    final qp = query.property(tString);
    expect(qp is PropertyQuery<String>, true);
    qp.close();

    query.close();
  });

  test('.sum integers', () {
    box.putMany(integerList());

    final query = box.query((tLong < 100)).build();
    final all = box.getAll();

    final sumByte = all.map((s) => s.tByte!).toList().fold(0, _add);
    final sumShort = all.map((s) => s.tShort!).toList().fold(0, _add);
    final sumInt = all.map((s) => toUint32(s.tInt!)).toList().fold(0, _add);
    final sumLong = all.map((s) => s.tLong!).toList().fold(0, _add);

    expect(_propQueryExec(query, tByte, _pqSumInt), sumByte);
    expect(_propQueryExec(query, tShort, _pqSumInt), sumShort);
    expect(_propQueryExec(query, tInt, _pqSumInt), sumInt);
    expect(_propQueryExec(query, tLong, _pqSumInt), sumLong);

    query.close();
  });

  test('.min integers', () {
    box.putMany(integerList());

    final query = box.query((tLong < 100)).build();
    final all = box.getAll();

    final minByte = all.map((s) => s.tByte!).toList().reduce(min);
    final minShort = all.map((s) => s.tShort!).toList().reduce(min);
    final minInt = all.map((s) => toUint32(s.tInt!)).toList().reduce(min);
    final minLong = all.map((s) => s.tLong!).toList().reduce(min);

    expect(_propQueryExec(query, tByte, _pqMinInt), minByte);
    expect(_propQueryExec(query, tShort, _pqMinInt), minShort);
    expect(_propQueryExec(query, tInt, _pqMinInt), minInt);
    expect(_propQueryExec(query, tLong, _pqMinInt), minLong);

    query.close();
  });

  test('.max integers', () {
    box.putMany(integerList());

    final query = box.query((tLong < 100)).build();
    final all = box.getAll();

    final maxByte = all.map((s) => s.tByte!).toList().reduce(max);
    final maxShort = all.map((s) => s.tShort!).toList().reduce(max);
    final maxInt = all.map((s) => toUint32(s.tInt!)).toList().reduce(max);
    final maxLong = all.map((s) => s.tLong!).toList().reduce(max);

    expect(_propQueryExec(query, tByte, _pqMaxInt), maxByte);
    expect(_propQueryExec(query, tShort, _pqMaxInt), maxShort);
    expect(_propQueryExec(query, tInt, _pqMaxInt), maxInt);
    expect(_propQueryExec(query, tLong, _pqMaxInt), maxLong);

    query.close();
  });

  test('.sum floats', () {
    box.putMany(floatList());

    final query = box.query((tFloat > -10.0).or(tDouble > -10.0)).build();

    final all = box.getAll();

    final sumFloat = all.map((s) => s.tFloat!).toList().fold(0.0, _add);
    final sumDouble = all.map((s) => s.tDouble!).toList().fold(0.0, _add);

    expect(_propQueryExec(query, tFloat, _pqSumDouble), sumFloat);
    expect(_propQueryExec(query, tDouble, _pqSumDouble), sumDouble);

    query.close();
  });

  test('.min floats', () {
    box.putMany(floatList());

    final query = box.query((tFloat > -10.0).or(tDouble > -10.0)).build();

    final all = box.getAll();

    final minFloat = all.map((s) => s.tFloat!).toList().reduce(min);
    final minDouble = all.map((s) => s.tDouble!).toList().reduce(min);

    expect(_propQueryExec(query, tFloat, _pqMinDouble), minFloat);
    expect(_propQueryExec(query, tDouble, _pqMinDouble), minDouble);

    query.close();
  });

  test('.max floats', () {
    box.putMany(floatList());

    final query = box.query((tFloat > -10.0).or(tDouble > -10.0)).build();
    final all = box.getAll();

    final maxFloat = all.map((s) => s.tFloat!).toList().reduce(max);
    final maxDouble = all.map((s) => s.tDouble!).toList().reduce(max);

    expect(_propQueryExec(query, tFloat, _pqMaxDouble), maxFloat);
    expect(_propQueryExec(query, tDouble, _pqMaxDouble), maxDouble);

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

    final start = [1, 2, 5];
    for (var i = 0; i < tSignedInts.length; i++) {
      final qp = queryIntegers.property(tSignedInts[i]);

      final mappedIntegers = integers.map((j) => j + start[i]).toList();
      expect(qp.find(replaceNullWith: -1), mappedIntegers);
      expect(qp.find(), mappedIntegers);

      qp.close();
    }

    tFloats.forEach((f) {
      final qp = queryFloats.property(f);

      final increment = tFloat == f ? 0.1 : 0.2;
      final expected =
          floats.map((f) => (f + increment).toStringAsFixed(2)).toList();

      expect(qp.find().map((f) => f.toStringAsFixed(2)).toList(), expected);

      qp.close();
    });

    final stringQuery = queryStrings.property(tString);

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
    var intUnsignedBaseAvg =
        integers.map(toUint32).reduce((a, b) => a + b) / integers.length;

    final qpInteger = (QueryIntegerProperty<TestEntity> p, double avg) {
      final qp = queryIntegers.property(p);
      expect(qp.average(), avg);
      qp.close();
    };

    qpInteger(tByte, intBaseAvg + 1);
    qpInteger(tLong, intBaseAvg + 5);
    qpInteger(tInt, intUnsignedBaseAvg + 4);
    qpInteger(tShort, intBaseAvg + 2);

    // floats
    final qpFloat = (QueryDoubleProperty<TestEntity> p, double avg) {
      final qp = queryFloats.property(p);
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
    final queryAndCheck = (QueryIntegerProperty<TestEntity> prop,
        int valueIfNull, String reason) {
      final qp = queryStrings.property(prop);
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
    final queryAndCheck = (QueryDoubleProperty<TestEntity> prop,
        double valueIfNull, String reason) {
      final qp = queryIntegers.property(prop);
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
    final qp = queryFloats.property(tString);
    expect(qp.find(replaceNullWith: 't').first, 't');
    qp.close();
    queryFloats.close();
  });

  test('.distinct, .count, .close property query', () {
    box.putMany(integerList());
    box.putMany(stringList());
    box.putMany(floatList());

    // int
    for (var i = 0; i < tSignedInts.length; i++) {
      final query = box.query(tSignedInts[i].lessThan(100)).build();
      final queryInt = query.property(tSignedInts[i]);

      expect(queryInt.distinct, false);
      expect(queryInt.count(), 9);
      expect((queryInt..distinct = true).count(), 7);
      expect(queryInt.distinct, true);
      queryInt.close();
      query.close();
    }

    // floats
    for (var i = 0; i < tFloats.length; i++) {
      final query = box.query(tFloats[i].lessThan(100.0)).build();
      final queryFloat = query.property(tFloats[i]);
      expect(queryFloat.distinct, false);
      expect(queryFloat.count(), 6);
      expect((queryFloat..distinct = true).count(), 4);
      expect(queryFloat.distinct, true);
      queryFloat.close();
      query.close();
    }

    // string
    final query =
        box.query(tString.contains('t', caseSensitive: false)).build();
    final queryString = query.property(tString);

    final allStrings = queryString.find()..sort();
    print('All items: $allStrings');

    final testStringPQ =
        ({required bool distinct, required bool caseSensitive}) {
      queryString
        ..distinct = distinct
        ..caseSensitive = caseSensitive;
      final items = queryString.find()..sort();

      final itemsDartMap =
          allStrings.map((s) => caseSensitive ? s : s.toLowerCase());
      final itemsDart =
          (distinct ? itemsDartMap.toSet() : itemsDartMap).toList()..sort();

      expect(items.map((s) => caseSensitive ? s : s.toLowerCase()).toList(),
          sameAsList(itemsDart));
      if (queryString.count() != itemsDart.length) {
        printOnFailure('$itemsDart');
        expect(queryString.count(), itemsDart.length);
      }
    };

    expect(queryString.count(), 8);

    // test without setting "caseSensitive" (implies the default TRUE)
    expect(queryString.distinct, false);
    expect((queryString..distinct = true).count(), 6);
    expect(queryString.distinct, true);

    expect(queryString.caseSensitive, true);
    testStringPQ(distinct: false, caseSensitive: false);
    expect(queryString.caseSensitive, false);
    testStringPQ(distinct: false, caseSensitive: true);
    expect(queryString.caseSensitive, true);
    testStringPQ(distinct: true, caseSensitive: false);
    testStringPQ(distinct: true, caseSensitive: true);
    queryString.close();
    query.close();
  });
}

T _add<T extends num>(T lhs, T rhs) => (lhs + rhs) as T;

int toUint32(int v) => v >= 0 ? v : (1 << 32) + v;

T _propQueryExec<T, DartType>(
    Query query,
    QueryProperty<TestEntity, DartType> prop,
    T Function(PropertyQuery<DartType> propQuery) fn) {
  final propQuery = query.property(prop);
  try {
    return fn(propQuery);
  } finally {
    propQuery.close();
  }
}

int _pqSumInt(PropertyQuery<int> propQuery) => propQuery.sum();

int _pqMinInt(PropertyQuery<int> propQuery) => propQuery.min();

int _pqMaxInt(PropertyQuery<int> propQuery) => propQuery.max();

double _pqSumDouble(PropertyQuery<double> propQuery) => propQuery.sum();

double _pqMinDouble(PropertyQuery<double> propQuery) => propQuery.min();

double _pqMaxDouble(PropertyQuery<double> propQuery) => propQuery.max();
