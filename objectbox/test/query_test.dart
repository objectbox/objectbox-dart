import 'package:collection/collection.dart';
import 'package:test/test.dart';

import 'entity.dart';
import 'entity2.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

// We want to have types explicit - verifying the return types of functions.
// ignore_for_file: omit_local_variable_types

void main() {
  late TestEnv env;
  late Box<TestEntity> box;

  setUp(() {
    env = TestEnv('query');
    box = env.box;
  });
  tearDown(() => env.closeAndDelete());

  test('Query auto-close', () {
    // Finalizer is executed after the query object goes out of scope.
    // Note: only caught by valgrind - I've tested that it actually catches
    // when the finalizer assignment was disabled. Now, this will only fail in
    // CI when running valgrind.sh - if finalizer won't work properly.
    box.query().build().find();
  });

  test('Query with no conditions, and order as desc ints', () {
    box.putMany(<TestEntity>[
      TestEntity(tInt: 0),
      TestEntity(tInt: 10),
      TestEntity(tInt: 100),
      TestEntity(tInt: 10),
      TestEntity(tInt: 0),
    ]);

    var query =
        (box.query()..order(TestEntity_.tInt, flags: Order.descending)).build();
    final listDesc = query.find();
    query.close();

    expect(listDesc.map((t) => t.tInt).toList(), [100, 10, 10, 0, 0]);
  });

  test('ignore transient field', () {
    box.put(TestEntity(tDouble: 0.1, ignore: 1337));

    final d = TestEntity_.tDouble;

    final q = box.query(d.between(0.0, 0.2)).build();

    expect(q.count(), 1);
    expect(q.findFirst()!.ignore, null);

    q.close();
  });

  test('ignore multiple transient fields', () {
    final entity = TestEntity.ignoredExcept(1337);

    box.put(entity);

    expect(entity.omit, -1);
    expect(entity.disregard, 1);

    final i = TestEntity_.tInt;

    final q = box.query(i.equals(1337)).build();

    final result = q.findFirst()!;

    expect(q.count(), 1);
    expect(result.disregard, null);
    expect(result.omit, null);

    q.close();
  });

  test('.null and .notNull', () {
    box.putMany(<TestEntity>[
      TestEntity(tDouble: 0.1, tBool: true),
      TestEntity(tDouble: 0.3, tBool: false),
      TestEntity(tString: 'one'),
      TestEntity(tString: 'two'),
    ]);

    final b = TestEntity_.tBool;
    final t = TestEntity_.tString;

    final qbNull = box.query(b.isNull()).build();
    final qbNotNull = box.query(b.notNull()).build();
    final qtNull = box.query(t.isNull()).build();
    final qtNotNull = box.query(t.notNull()).build();
    final qdNull = box.query(t.isNull()).build();
    final qdNotNull = box.query(t.notNull()).build();

    [qbNull, qbNotNull, qtNull, qtNotNull, qdNull, qdNotNull].forEach((q) {
      expect(q.count(), 2);
      q.close();
    });
  });

  test('string case-sensitivity', () {
    final testCaseSensitivity = (Box<TestEntity> box, bool defaultIsTrue) {
      box.put(TestEntity(tString: 'Hello'));
      box.put(TestEntity(tString: 'hello'));

      final t = TestEntity_.tString;

      final q1 = box.query(t.startsWith('hello')).build();
      expect(q1.count(), 1 + (defaultIsTrue ? 0 : 1));

      final q2 = box.query(t.startsWith('hello', caseSensitive: true)).build();
      expect(q2.count(), 1);

      final q3 = box.query(t.startsWith('Hello', caseSensitive: true)).build();
      expect(q3.count(), 1);

      final q4 = box.query(t.endsWith('ello', caseSensitive: true)).build();
      expect(q4.count(), 2);

      [q1, q2, q3, q4].forEach((q) => q.close());
    };
    final env1 = TestEnv('query1', queryCaseSensitive: true);
    final env2 = TestEnv('query2', queryCaseSensitive: false);

    // current default: case insensitive
    testCaseSensitivity(env.box, true);
    testCaseSensitivity(env1.box, true);
    testCaseSensitivity(env2.box, false);

    env1.closeAndDelete();
    env2.closeAndDelete();
  });

  test('.count doubles and booleans', () {
    box.putMany(<TestEntity>[
      TestEntity(tDouble: 0.1, tBool: true),
      TestEntity(tDouble: 0.3, tBool: false),
      TestEntity(tDouble: 0.5, tBool: true),
      TestEntity(tDouble: 0.7, tBool: false),
      TestEntity(tDouble: 0.9, tBool: true)
    ]);

    final d = TestEntity_.tDouble;
    final b = TestEntity_.tBool;

    final anyQuery0 = (d.between(0.79, 0.81) & b.equals(false) |
        (d.between(0.69, 0.71) & b.equals(false)));
    final anyQuery1 = (d.between(0.79, 0.81).and(b.equals(false)))
        .or(d.between(0.69, 0.71).and(b.equals(false)));
    final anyQuery2 = d
        .between(0.79, 0.81)
        .and(b.equals(false))
        .or(d.between(0.69, 0.71).and(b.equals(false)));
    final anyQuery3 = d
        .between(0.79, 0.81)
        .and(b.equals(false))
        .or(d.between(0.69, 0.71))
        .and(b.equals(false));

    final allQuery0 = d.between(0.09, 0.11) & b.equals(true);

    final q0 = box.query(b.equals(false)).build();
    final qany0 = box.query(anyQuery0).build();
    final qany1 = box.query(anyQuery1).build();
    final qany2 = box.query(anyQuery2).build();
    final qany3 = box.query(anyQuery3).build();

    final qall0 = box.query(allQuery0).build();

    expect(q0.count(), 2);
    expect(qany0.count(), 1);
    expect(qany1.count(), 1);
    expect(qany2.count(), 1);
    expect(qany3.count(), 1);
    expect(qall0.count(), 1);

    [q0, qany0, qany1, qany2, qany3, qall0].forEach((q) => q.close());
  });

  test('between ints', () {
    box.putMany(<TestEntity>[
      TestEntity(tInt: 1),
      TestEntity(tInt: 3),
      TestEntity(tInt: 5),
      TestEntity(tInt: 7),
      TestEntity(tInt: 9)
    ]);

    expect(box.query(TestEntity_.tInt.between(3, 7)).build().count(), 3);
  });

  test('.count matches of `greater` and `less`', () {
    box.putMany(<TestEntity>[
      TestEntity(tLong: 1336, tString: 'mord'),
      TestEntity(tLong: 1337, tString: 'more'),
      TestEntity(tLong: 1338, tString: 'morf'),
      TestEntity(tDouble: 0.0, tBool: false),
      TestEntity(tDouble: 0.1, tBool: true),
      TestEntity(tDouble: 0.2, tBool: true),
      TestEntity(tDouble: 0.3, tBool: false),
    ]);

    final d = TestEntity_.tDouble;
    final b = TestEntity_.tBool;
    final t = TestEntity_.tString;
    final n = TestEntity_.tLong;

    final checkQueryCount =
        (int expectedCount, Condition<TestEntity> condition) {
      final query = box.query(condition).build();
      expect(query.count(), expectedCount);
      query.close();
    };

    checkQueryCount(2, b.equals(false));
    checkQueryCount(1, t.greaterThan('more'));
    checkQueryCount(2, t.greaterOrEqual('more'));
    checkQueryCount(1, t.lessThan('more'));
    checkQueryCount(2, t.lessOrEqual('more'));
    checkQueryCount(2, d.greaterThan(0.1));
    checkQueryCount(3, d.greaterOrEqual(0.1));
    checkQueryCount(3, d.lessThan(0.3));
    checkQueryCount(4, d.lessOrEqual(0.3));
    checkQueryCount(1, n.lessThan(1337));
    checkQueryCount(2, n.lessOrEqual(1337));
    checkQueryCount(1, n.greaterThan(1337));
    checkQueryCount(2, n.greaterOrEqual(1337));
  });

  test('.count matches of `in`, `contains`', () {
    box.put(TestEntity(tLong: 1337, tString: 'meh'));
    box.put(TestEntity(tLong: 1, tString: 'bleh'));
    box.put(TestEntity(tLong: 1337, tString: 'bleh'));
    box.put(TestEntity(tLong: 1337, tString: 'blh'));

    final text = TestEntity_.tString;
    final number = TestEntity_.tLong;

    final qs0 = box.query(text.oneOf(['meh'])).build();
    final qs1 = box.query(text.oneOf(['bleh'])).build();
    final qs2 = box.query(text.oneOf(['meh', 'bleh'])).build();
    // TODO native qb_not_in_strings()
    //  final qs2 = box.query(text.notOneOf(['oof'])).build();
    final qs3 = box.query(text.contains('eh')).build();

    final qn0 = box.query(number.oneOf([1])).build();
    final qn1 = box.query(number.notOneOf([1])).build();
    final qn2 = box.query(number.oneOf([1, 1337])).build();

    expect(qs0.count(), 1);
    expect(qs1.count(), 2);
    expect(qs2.count(), 3);
    expect(qs3.count(), 3);
    expect(qn0.count(), 1);
    expect(qn1.count(), 3);
    expect(qn2.count(), 4);

    [qs0, qs1, qs2, qs3, qn0, qn1, qn2].forEach((q) => q.close());
  });

  test('.count matches of List<String> `contains`', () {
    box.put(TestEntity(tStrings: ['foo', 'bar']));
    box.put(TestEntity(tStrings: ['barbar']));
    box.put(TestEntity(tStrings: ['foo']));

    final prop = TestEntity_.tStrings;

    final qs0 = box.query(prop.contains('bar')).build();
    expect(qs0.count(), 1);

    final qs1 = box.query(prop.contains('ar')).build();
    expect(qs1.count(), 0);

    final qs2 = box.query(prop.contains('foo')).build();
    expect(qs2.count(), 2);

    [qs0, qs1, qs2].forEach((q) => q.close());
  });

  test('.findIds returns List<int>', () {
    box.put(TestEntity(tString: null));
    box.put(TestEntity(tString: 'bleh'));
    box.put(TestEntity(tString: 'bleh'));
    box.put(TestEntity(tString: 'helb'));
    box.put(TestEntity(tString: 'helb'));
    box.put(TestEntity(tString: 'bleh'));
    box.put(TestEntity(tString: 'blh'));

    final text = TestEntity_.tString;

    final q0 = box.query(text.notNull()).build();
    final result0 = q0.findIds();

    final q2 = box.query(text.equals('blh')).build();
    final result2 = q2.findIds();

    final q3 = box.query(text.equals("can't find this")).build();
    final result3 = q3.findIds();

    expect(result0, sameAsList([2, 3, 4, 5, 6, 7]));
    expect(result2, sameAsList([7]));
    expect(result3.isEmpty, isTrue);

    q0.close();
    q2.close();
    q3.close();

    // paranoia
    [result0, result2, result3].forEach((ids) => ids.forEach((id) {
          final read = box.get(id)!;
          expect(read, isNotNull);
          expect(read.id, equals(id));
        }));
  });

  test('.find offset and limit', () {
    box.put(TestEntity());
    box.put(TestEntity(tString: 'a'));
    box.put(TestEntity(tString: 'b'));
    box.put(TestEntity(tString: 'c'));

    var q = box.query().build();
    expect(q.find().length, 4);

    expect((q..offset = 2).find().map((e) => e.tString), equals(['b', 'c']));
    expect((q..limit = 1).find().map((e) => e.tString), equals(['b']));
    expect((q..offset = 0).find().map((e) => e.tString), equals([null]));

    q.close();
  });

  test('.findFirst returns TestEntity', () {
    box.put(TestEntity(tLong: 0));
    box.put(TestEntity(tString: 'test1t'));
    box.put(TestEntity(tString: 'test'));

    final text = TestEntity_.tString;
    final number = TestEntity_.tLong;

    final c = text.startsWith('t') & text.endsWith('t');

    var q = box.query(c).build();

    expect(q.findFirst()!.tString, 'test1t');
    q.close();

    q = box.query(number.notNull()).build();
    expect(q.findFirst()!.tLong, 0);
    q.close();
  });

  test('.findUnique', () {
    box.put(TestEntity(tLong: 0));
    box.put(TestEntity(tString: 't1'));
    box.put(TestEntity(tString: 't2'));

    var query = box.query(TestEntity_.tString.startsWith('t')).build();

    expect(
        () => query.findUnique(),
        throwsA(predicate((UniqueViolationException e) =>
            e.toString().contains('more than one'))));

    query.param(TestEntity_.tString).value = 't2';
    expect(query.findUnique()!.tString, 't2');

    query.param(TestEntity_.tString).value = 'xyz';
    expect(query.findUnique(), isNull);
  });

  test('.find works on large arrays', () {
    // This would fail on 32-bit system if objectbox-c obx_supports_bytes_array() wasn't respected
    final length = 10 * 1000;
    final largeString = 'A' * length;
    expect(largeString.length, length);

    box.put(TestEntity(tString: largeString));
    box.put(TestEntity(tString: largeString));
    box.put(TestEntity(tString: largeString));

    final query = box.query(TestEntity_.id.lessThan(3)).build();
    List<TestEntity> items = query.find();
    expect(items.length, 2);
    expect(items[0].tString, largeString);
    expect(items[1].tString, largeString);
    query.close();
  });

  test('.remove deletes the right items', () {
    box.put(TestEntity());
    box.put(TestEntity(tString: 'test'));
    box.put(TestEntity(tString: 'test3'));
    box.put(TestEntity(tString: 'foo'));

    final text = TestEntity_.tString;

    final q = box.query(text.startsWith('test')).build();
    expect(q.remove(), 2);
    q.close();

    final remaining = box.getAll();
    expect(remaining.length, 2);
    expect(remaining.map((e) => e.id), equals([1, 4]));
  });

  test('.count items after grouping with and/or', () {
    box.put(TestEntity(tString: 'Hello'));
    box.put(TestEntity(tString: 'Goodbye'));
    box.put(TestEntity(tString: 'World'));

    box.put(TestEntity(tLong: 1337));
    box.put(TestEntity(tLong: 80085));

    box.put(TestEntity(tLong: -1337, tString: 'meh'));
    box.put(TestEntity(tLong: -1332 + -5, tString: 'bleh'));
    box.put(TestEntity(tLong: 1337, tString: 'Goodbye'));

    final text = TestEntity_.tString;
    final number = TestEntity_.tLong;

    Condition<TestEntity> cond1 = text.equals('Hello') | number.equals(1337);
    Condition<TestEntity> cond2 = text.equals('Hello') | number.equals(1337);
    Condition<TestEntity> cond3 =
        text.equals('What?').and(text.equals('Hello')).or(text.equals('World'));
    Condition<TestEntity> cond4 = text
        .equals('Goodbye')
        .and(number.equals(1337))
        .or(number.equals(1337))
        .or(text.equals('Cruel'))
        .or(text.equals('World'));
    Condition<TestEntity> cond5 = text.equals('bleh') & number.equals(-1337);
    Condition<TestEntity> cond6 = text.equals('Hello') & number.equals(1337);

    final q1 = box.query(cond1).build();
    final q2 = box.query(cond2).build();
    final q3 = box.query(cond3).build();
    final q4 = box.query(cond4).build();
    final q5 = box.query(cond5).build();
    final q6 = box.query(cond6).build();

    expect(q1.count(), 3);
    expect(q2.count(), 3);
    expect(q3.count(), 1);
    expect(q4.count(), 3);
    expect(q5.count(), 1);
    expect(q6.count(), 0);

    [q1, q2, q3, q4, q5, q6].forEach((q) => q.close());
  });

  test('.describe query', () {
    final text = TestEntity_.tString;
    final number = TestEntity_.tLong;
    Condition<TestEntity> c = text
        .equals('Goodbye')
        .and(number.equals(1337))
        .or(number.equals(1337))
        .or(text.equals('Cruel'))
        .or(text.equals('World'));
    final q = box.query(c).build();
    // 5 partial conditions, + 1 'and' + 1 'any' = 7 conditions
    // note: order of properties is not guaranteed (currently OS specific).
    expect(
        q.describe(),
        matches(
            'Query for entity TestEntity with 7 conditions with properties (tLong, tString|tString, tLong)'));
    q.close();

    for (var j = 1; j < 20; j++) {
      var tc = text.equals('Hello');
      for (var i = 0; i < j; i++) {
        tc = tc.or(text.endsWith('lo'));
      }
      final q = box.query(tc).build();
      expect(q.describe(),
          '''Query for entity TestEntity with ${j + 2} conditions with properties tString''');
      q.close();
    }

    for (var j = 1; j < 20; j++) {
      var tc = text.equals('Hello');
      for (var i = 0; i < j; i++) {
        tc = tc.and(text.startsWith('lo'));
      }
      final q = box.query(tc).build();
      expect(q.describe(),
          '''Query for entity TestEntity with ${j + 2} conditions with properties tString''');
      q.close();
    }
  });

  test('query condition grouping', () {
    final n = TestEntity_.id;
    final b = TestEntity_.tBool;

    final check = (Condition<TestEntity> condition, String text) {
      final q = box.query(condition).build();
      expect(q.describeParameters(), text);
      q.close();
    };

    check((n.equals(0) & b.equals(false)) | (n.equals(1) & b.equals(true)),
        '((id == 0\n AND tBool == 0)\n OR (id == 1\n AND tBool == 1))');
    check(n.equals(0) & b.equals(false) | n.equals(1) & b.equals(true),
        '((id == 0\n AND tBool == 0)\n OR (id == 1\n AND tBool == 1))');
    check((n.equals(0) & b.equals(false)) | (n.equals(1) | b.equals(true)),
        '((id == 0\n AND tBool == 0)\n OR (id == 1\n OR tBool == 1))');
    check((n.equals(0) & b.equals(false)) | n.equals(1) | b.equals(true),
        '((id == 0\n AND tBool == 0)\n OR id == 1\n OR tBool == 1)');
    check(n.equals(0) | b.equals(false) & n.equals(1) | b.equals(true),
        '(id == 0\n OR (tBool == 0\n AND id == 1)\n OR tBool == 1)');
  });

  test('.describeParameters query', () {
    final text = TestEntity_.tString;
    final long = TestEntity_.tLong;
    final int = TestEntity_.tInt;
    final double = TestEntity_.tDouble;
    final bool = TestEntity_.tBool;
    Condition<TestEntity> c = text
        .equals('Goodbye')
        .and(long.equals(1337))
        .or(long.notEquals(1337))
        .or(long > 1337)
        .or(long < 1337)
        .or(double > 1.3)
        .or(double < 1.3)
        .or(int.oneOf([2]))
        .or(int.notOneOf([4]))
        .or(bool.notEquals(true))
        .or(text.equals('Cruel'))
        .or(text.notEquals('World'));
    final q = box.query(c).build();
    final expectedString = [
      '((tString == "Goodbye"',
      ' AND tLong == 1337)',
      ' OR tLong != 1337',
      ' OR tLong > 1337',
      ' OR tLong < 1337',
      ' OR tDouble > 1.300000',
      ' OR tDouble < 1.300000',
      ' OR tInt in [2]',
      ' OR tInt not in [4]',
      ' OR tBool != 1',
      ' OR tString == "Cruel"',
      ' OR tString != "World")'
    ].join('\n');
    expect(q.describeParameters(), expectedString);
    q.close();

    for (var j = 1; j < 20; j++) {
      var tc = text.equals('Goodbye');
      var expected = ['''tString == "Goodbye"'''];
      for (var i = 0; i < j; i++) {
        tc = tc.and(text.endsWith('ye'));
        expected.add(''' AND tString ends with "ye"''');
      }
      final q = box.query(tc).build();
      expect(q.describeParameters(), '''(${expected.join("\n")})''');
      q.close();
    }

    for (var j = 1; j < 20; j++) {
      var tc = text.equals('Goodbye');
      var expected = ['''tString == "Goodbye"'''];
      for (var i = 0; i < j; i++) {
        tc = tc.or(text.startsWith('Good'));
        expected.add(''' OR tString starts with "Good"''');
      }
      final q = box.query(tc).build();
      expect(q.describeParameters(), '''(${expected.join("\n")})''');
      q.close();
    }
  });

  test('orAny() & andAll()', () {
    final p = TestEntity_.tInt;
    expect(
        box
            .query((p > 1)
                .or(p > 2)
                .orAny([p > 3, p > 4])
                .and(p < 5)
                .andAll([p < 6, p < 7]))
            .build()
            .describeParameters(),
        [
          '((tInt > 1',
          ' OR tInt > 2',
          ' OR tInt > 3',
          ' OR tInt > 4)',
          ' AND tInt < 5',
          ' AND tInt < 6',
          ' AND tInt < 7)',
        ].join('\n'));
  });

  test('.order queryBuilder', () {
    box.put(TestEntity(tString: 'World'));
    box.put(TestEntity(tString: 'Hello'));
    box.put(TestEntity(tString: 'HELLO'));
    box.put(TestEntity(tString: 'World'));
    box.put(TestEntity(tString: 'Goodbye'));
    box.put(TestEntity(tString: 'Cruel'));
    box.put(TestEntity(tLong: 1337));

    final text = TestEntity_.tString;

    final condition = text.notNull();

    final query = (box.query(condition)..order(text)).build();
    final result1 = query.find().map((e) => e.tString).toList();

    expect('Cruel', result1[0]);
    expect('Hello', result1[2]);
    expect('HELLO', result1[3]);

    final queryReverseOrder = (box.query(condition)
          ..order(text, flags: Order.descending | Order.caseSensitive))
        .build();
    final result2 = queryReverseOrder.find().map((e) => e.tString).toList();

    expect('World', result2[0]);
    expect('Hello', result2[2]);
    expect('HELLO', result2[3]);

    query.close();
    queryReverseOrder.close();
  });

  test('.order signed/unsigned', () {
    for (int i = -1; i <= 1; i++) {
      box.put(TestEntity(tLong: i, tInt: i));
    }

    final querySigned = (box.query()..order(TestEntity_.tLong)).build();
    final queryUnsigned = (box.query()..order(TestEntity_.tInt)).build();

    expect(querySigned.findIds(), [1, 2, 3]);
    expect(queryUnsigned.findIds(), [2, 3, 1]);

    querySigned.close();
    queryUnsigned.close();
  });

  test('.describeParameters BytesVector', () {
    final q = box
        .query(TestEntity_.tUint8List.equals([1, 2]) &
            TestEntity_.tInt8List.greaterThan([3, 4]) &
            TestEntity_.tByteList.greaterOrEqual([5, 6, 7]) &
            TestEntity_.tUint8List.lessThan([8]) &
            TestEntity_.tUint8List.lessOrEqual([9, 10, 11, 12]))
        .build();
    expect(
        q.describeParameters(),
        equals('(tUint8List == byte[2]{0x0102}\n'
            ' AND tInt8List > byte[2]{0x0304}\n'
            ' AND tByteList >= byte[3]{0x050607}\n'
            ' AND tUint8List < byte[1]{0x08}\n'
            ' AND tUint8List <= byte[4]{0x090A0B0C})'));
    q.close();
  });

  testStream({required bool useIsolateStream}) async {
    final count = env.short ? 100 : 1000;
    final items = List<TestEntity>.generate(
        count, (i) => TestEntity.filled(id: 0, tByte: i % 30));
    box.putMany(items);
    expect(box.count(), count);

    final query = box.query(TestEntity_.tByte.lessThan(10)).build();
    final countMatching =
        items.fold(0, (int c, item) => c + (item.tByte! < 10 ? 1 : 0));
    expect(query.count(), countMatching);

    final foundIds = query.findIds();
    final stream =
        useIsolateStream ? await query.streamAsync() : query.stream();
    final streamed = await stream.toList();
    expect(streamed.length, countMatching);
    final streamedIds = streamed.map((e) => e.id).toList(growable: false);

    // this is much much slower: expect(streamedIds, sameAsList(foundIds));
    expect(const ListEquality<int>().equals(streamedIds, foundIds), isTrue);

    // Test subscription cancellation doesn't leave non-freed resources.
    final streamListenedItems = <TestEntity>{};

    final start = DateTime.now();
    final subStream =
        useIsolateStream ? await query.streamAsync() : query.stream();
    final subscription = subStream.listen(streamListenedItems.add);
    for (int i = 0; i < 10 && streamListenedItems.isEmpty; i++) {
      await Future<void>.delayed(Duration(milliseconds: i));
    }
    print('Received ${streamListenedItems.length} items in '
        '${DateTime.now().difference(start).inMilliseconds} milliseconds');
    await subscription.cancel();
    expect(streamListenedItems.length, isNonZero);

    query.close();
  }

  test('stream items', () async {
    await testStream(useIsolateStream: false);
  });

  test('stream items via isolate', () async {
    await testStream(useIsolateStream: true);
  });

  test('set param single', () async {
    final query = box
        .query(TestEntity_.tString.equals('') |
            TestEntity_.tByteList.equals([]) |
            TestEntity_.tInt.equals(0) |
            TestEntity_.tDouble.lessThan(0) |
            TestEntity_.tBool.equals(false))
        .build();
    query
      ..param(TestEntity_.tString).value = 'foo'
      ..param(TestEntity_.tByteList).value = [1, 9]
      ..param(TestEntity_.tInt).value = 11
      ..param(TestEntity_.tDouble).value = 4.6
      ..param(TestEntity_.tBool).value = true;
    expect(
        query.describeParameters(),
        [
          '(tString == "foo"',
          ' OR tByteList == byte[2]{0x0109}',
          ' OR tInt == 11',
          ' OR tDouble < 4.600000',
          ' OR tBool == 1)',
        ].join('\n'));
  });

  test('set two params', () async {
    final query = box
        .query(
            TestEntity_.tInt.between(0, 0) | TestEntity_.tDouble.between(0, 0))
        .build();
    query.param(TestEntity_.tInt).twoValues(1, 2);
    query.param(TestEntity_.tDouble).twoValues(1.2, 3.4);
    expect(
        query.describeParameters(),
        [
          '(tInt between 1 and 2',
          ' OR tDouble between 1.200000 and 3.400000)',
        ].join('\n'));
  });

  test('set params list', () async {
    final q1 = box.query(TestEntity_.tString.oneOf([])).build()
      ..param(TestEntity_.tString).values = ['foo', 'bar'];
    if (!['tString in ["foo", "bar"]', 'tString in ["bar", "foo"]']
        .contains(q1.describeParameters())) {
      fail('Invalid query: ' + q1.describeParameters());
    }

    final q2 = box.query(TestEntity_.tInt.oneOf([])).build()
      ..param(TestEntity_.tInt).values = [1, 2];

    if (!['tInt in [1|2]', 'tInt in [2|1]'].contains(q2.describeParameters())) {
      fail('Invalid query: ' + q2.describeParameters());
    }

    final q3 = box.query(TestEntity_.tLong.oneOf([])).build()
      ..param(TestEntity_.tLong).values = [1, 2];

    if (!['tLong in [1|2]', 'tLong in [2|1]']
        .contains(q3.describeParameters())) {
      fail('Invalid query: ' + q3.describeParameters());
    }
  });

  test('alias - set param single', () async {
    final query = box
        .query(TestEntity_.tString.equals('') |
            TestEntity_.tByteList.equals([]) |
            TestEntity_.tInt.equals(0) |
            TestEntity_.tDouble.lessThan(0) |
            TestEntity_.tBool.equals(false) |
            TestEntity_.tString.equals('', alias: 'str') |
            TestEntity_.tByteList.equals([], alias: 'bytes') |
            TestEntity_.tInt.equals(0, alias: 'int') |
            TestEntity_.tDouble.lessThan(0, alias: 'double') |
            TestEntity_.tBool.equals(false, alias: 'bool'))
        .build();
    query
      ..param(TestEntity_.tString, alias: 'str').value = 'foo'
      ..param(TestEntity_.tByteList, alias: 'bytes').value = [1, 9]
      ..param(TestEntity_.tInt, alias: 'int').value = 11
      ..param(TestEntity_.tDouble, alias: 'double').value = 4.6
      ..param(TestEntity_.tBool, alias: 'bool').value = true;
    expect(
        query.describeParameters(),
        [
          '(tString == ""',
          ' OR tByteList == byte[0]""',
          ' OR tInt == 0',
          ' OR tDouble < 0.000000',
          ' OR tBool == 0',
          ' OR tString == "foo"',
          ' OR tByteList == byte[2]{0x0109}',
          ' OR tInt == 11',
          ' OR tDouble < 4.600000',
          ' OR tBool == 1)',
        ].join('\n'));
  });

  test('alias - set two params', () async {
    final query = box
        .query(TestEntity_.tInt.between(0, 0) |
            TestEntity_.tDouble.between(0, 0) |
            TestEntity_.tInt.between(0, 0, alias: 'int') |
            TestEntity_.tDouble.between(0, 0, alias: 'double'))
        .build();
    query.param(TestEntity_.tInt, alias: 'int').twoValues(1, 2);
    query.param(TestEntity_.tDouble, alias: 'double').twoValues(1.2, 3.4);
    expect(
        query.describeParameters(),
        [
          '(tInt between 0 and 0',
          ' OR tDouble between 0.000000 and 0.000000',
          ' OR tInt between 1 and 2',
          ' OR tDouble between 1.200000 and 3.400000)',
        ].join('\n'));
  });

  test('alias - set params list', () async {
    final q1 = box
        .query(TestEntity_.tString.oneOf([]) |
            TestEntity_.tString.oneOf([], alias: 'a'))
        .build()
      ..param(TestEntity_.tString, alias: 'a').values = ['foo', 'bar'];
    if (!['OR tString in ["foo", "bar"]', 'OR tString in ["bar", "foo"]']
        .any(q1.describeParameters().contains)) {
      fail('Invalid query: ' + q1.describeParameters());
    }

    final q2 = box
        .query(
            TestEntity_.tInt.oneOf([]) | TestEntity_.tInt.oneOf([], alias: 'a'))
        .build()
      ..param(TestEntity_.tInt, alias: 'a').values = [1, 2];

    if (!['OR tInt in [1|2]', 'OR tInt in [2|1]']
        .any(q2.describeParameters().contains)) {
      fail('Invalid query: ' + q2.describeParameters());
    }

    final q3 = box
        .query(TestEntity_.tLong.oneOf([]) |
            TestEntity_.tLong.oneOf([], alias: 'a'))
        .build()
      ..param(TestEntity_.tLong, alias: 'a').values = [1, 2];

    if (!['OR tLong in [1|2]', 'OR tLong in [2|1]']
        .any(q3.describeParameters().contains)) {
      fail('Invalid query: ' + q3.describeParameters());
    }
  });

  test('set param on links', () async {
    final query = (box.query(TestEntity_.tString.equals(''))
          ..link(TestEntity_.relB, RelatedEntityB_.tString.equals(''))
          ..linkMany(TestEntity_.relManyA, RelatedEntityA_.tInt.equals(0)))
        .build();
    query
      ..param(TestEntity_.tString).value = 'foo'
      ..param(RelatedEntityB_.tString).value = 'bar'
      ..param(RelatedEntityA_.tInt).value = 11;
    expect(
        query.describeParameters(),
        [
          'tString == "foo"',
          '| Link RelatedEntityB via relBId with conditions: tString == "bar"',
          '| Link RelatedEntityA via standalone Relation 1 (from entity 1 to 4) with conditions: tInt == 11',
        ].join('\n'));
  });

  test('throwing in converters', () {
    late Box<ThrowingInConverters> box = env.store.box();

    box.put(ThrowingInConverters(throwOnGet: true));
    box.put(ThrowingInConverters());

    final query = box.query().build();
    expect(query.count(), 2);
    expect(query.findIds().length, 2);

    expect(query.findFirst, ThrowingInConverters.throwsIn('Setter'));
    expect(query.find, ThrowingInConverters.throwsIn('Setter'));
  });
}
