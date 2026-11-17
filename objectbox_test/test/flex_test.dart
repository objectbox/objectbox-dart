import 'package:test/test.dart';

import 'entity_flex.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

// We want to have types explicit - verifying the return types of functions.
// ignore_for_file: omit_local_variable_types

void main() {
  late TestEnv env;
  late Store store;

  setUp(() {
    env = TestEnv('flex');
    store = env.store;
  });

  tearDown(() => env.closeAndDelete());

  /// Runs [Query.findIds] and checks the returned object IDs match the given
  /// [expectedIds].
  void assertQueryCondition<E>(
    Condition<E> condition,
    Box<E> box,
    List<int> expectedIds,
  ) {
    final query = box.query(condition).build();
    try {
      final results = query.findIds();
      expect(results, unorderedEquals(expectedIds));
    } finally {
      query.close();
    }
  }

  group('Flex Map property (Map<String, dynamic>)', () {
    late Box<FlexMapEntity> box;

    setUp(() {
      box = store.box<FlexMapEntity>();
    });

    test('put and get with default values', () {
      final entity = FlexMapEntity();
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexDynamic, isNull);
      expect(read.flexObject, isNull);
      expect(read.flexNonNull, isEmpty);
      expect(read.flexExplicit, isNull);
    });

    test('put and get map with various value types', () {
      final testMap = {
        'string': 'hello',
        'int': 42,
        'double': 3.14,
        'bool': false,
      };
      final testMapWithNull = <String, Object?>{'null': null}..addAll(testMap);
      final entity = FlexMapEntity(
        flexDynamic: testMapWithNull,
        flexObject: testMapWithNull,
        flexObjectNonNull: testMap,
        flexNonNull: testMapWithNull,
        flexExplicit: testMapWithNull,
      );
      final id = box.put(entity);

      assertTestMap(Map<String, dynamic> map) {
        expect(map['string'], 'hello');
        expect(map['int'], 42);
        expect(map['double'], 3.14);
        expect(map['bool'], false);
      }

      assertTestMapWithNull(Map<String, dynamic> map) {
        assertTestMap(map);
        expect(map['null'], isNull);
        // The map also returns null if it doesn't contain the key,
        // so explicitly check it does.
        expect(map.containsKey('null'), true);
      }

      final read = box.get(id)!;
      assertTestMapWithNull(read.flexDynamic!);
      assertTestMapWithNull(read.flexObject!);
      assertTestMap(read.flexObjectNonNull!);
      assertTestMapWithNull(read.flexNonNull);
      assertTestMapWithNull(read.flexExplicit!);
    });

    test('put and get nested map', () {
      final entity = FlexMapEntity(
        flexDynamic: {
          'user': {
            'name': 'Bob',
            'address': {'city': 'Berlin', 'zip': '10115'},
          },
        },
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      final user = read.flexDynamic!['user'] as Map<String, dynamic>;
      expect(user['name'], 'Bob');
      final address = user['address'] as Map<String, dynamic>;
      expect(address['city'], 'Berlin');
      expect(address['zip'], '10115');
    });

    test('put and get map with list values', () {
      final entity = FlexMapEntity(
        flexDynamic: {
          'tags': ['dart', 'flutter', 'objectbox'],
          'scores': [95, 87, 92],
          'mixed': [1, 'two', 3.0, true, null],
        },
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexDynamic!['tags'], ['dart', 'flutter', 'objectbox']);
      expect(read.flexDynamic!['scores'], [95, 87, 92]);
      expect(read.flexDynamic!['mixed'], [1, 'two', 3.0, true, null]);
    });

    test('put and get complex nested structure', () {
      final entity = FlexMapEntity(
        flexDynamic: {
          'users': [
            {
              'name': 'Alice',
              'roles': ['admin', 'user'],
            },
            {
              'name': 'Bob',
              'roles': ['user'],
            },
          ],
          'metadata': {
            'version': 1,
            'features': ['flex', 'sync'],
          },
        },
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      final users = read.flexDynamic!['users'] as List;
      expect(users.length, 2);
      expect((users[0] as Map)['name'], 'Alice');
      expect((users[0] as Map)['roles'], ['admin', 'user']);
      final metadata = read.flexDynamic!['metadata'] as Map<String, dynamic>;
      expect(metadata['version'], 1);
      expect(metadata['features'], ['flex', 'sync']);
    });

    test('update map value', () {
      final entity = FlexMapEntity(flexDynamic: {'count': 1});
      final id = box.put(entity);

      // Update
      final read = box.get(id)!;
      read.flexDynamic = {'count': 2, 'updated': true};
      box.put(read);

      // Verify update
      final updated = box.get(id)!;
      expect(updated.flexDynamic!['count'], 2);
      expect(updated.flexDynamic!['updated'], true);
    });

    test('set map to null', () {
      final entity = FlexMapEntity(flexDynamic: {'data': 'exists'});
      final id = box.put(entity);

      // Set to null
      final read = box.get(id)!;
      read.flexDynamic = null;
      box.put(read);

      // Verify null
      final updated = box.get(id)!;
      expect(updated.flexDynamic, isNull);
    });

    test('empty map is stored and retrieved correctly', () {
      final entity = FlexMapEntity(flexDynamic: {});
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexDynamic, isNotNull);
      expect(read.flexDynamic, isEmpty);
    });

    test('putMany and getAll', () {
      final entities = [
        FlexMapEntity(flexDynamic: {'index': 0}),
        FlexMapEntity(flexDynamic: {'index': 1}),
        FlexMapEntity(flexDynamic: {'index': 2}),
      ];
      box.putMany(entities);

      final all = box.getAll();
      expect(all.length, 3);
      for (var i = 0; i < 3; i++) {
        expect(all[i].flexDynamic!['index'], i);
      }
    });

    FlexMapEntity createObjectWithStringObjectMap(String s, int l, double d) {
      final entity = FlexMapEntity();
      final map = <String, Object>{
        'key-string': s,
        'key-long': l,
        'key-double': d,
      };
      entity.flexDynamic = map;
      entity.flexObject = map;
      entity.flexObjectNonNull = map;
      entity.flexNonNull = map;
      entity.flexExplicit = map;
      return entity;
    }

    List<FlexMapEntity> createObjectsWithStringObjectMap() {
      return [
        createObjectWithStringObjectMap('apple', -1, -0.2),
        createObjectWithStringObjectMap('Cherry', 3, -1234.56),
        createObjectWithStringObjectMap('Apple', 234234234, 1234.56),
        createObjectWithStringObjectMap('pineapple', -567, 0.1),
      ];
    }

    test('containsElement_stringObjectMap', () {
      final entity1 = FlexMapEntity();
      entity1.flexObject = {'key-string': 'apple', 'key-int': 123};
      final entity2 = FlexMapEntity();
      entity2.flexObject = {'KEY-STRING': 'banana', 'key-long': 456};
      box.putMany([entity1, entity2]);
      final id1 = entity1.id;
      final id2 = entity2.id;

      assertQueryCondition(
        FlexMapEntity_.flexObject.containsElement(
          'key-string',
          caseSensitive: true,
        ),
        box,
        [id1],
      );
      assertQueryCondition(
        FlexMapEntity_.flexObject.containsElement(
          'key-string',
          caseSensitive: false,
        ),
        box,
        [id1, id2],
      );
    });

    test('equalsKeyValue', () {
      final objects = createObjectsWithStringObjectMap();
      box.putMany(objects);
      final largeCherry = objects[1].id;
      final largeApple = objects[2].id;

      assertQueryCondition(
        FlexMapEntity_.flexObject.equalsKeyValueString('key-string', 'Apple'),
        box,
        [largeApple],
      );
      assertQueryCondition(
        FlexMapEntity_.flexObject.equalsKeyValueInt('key-long', 234234234),
        box,
        [largeApple],
      );
      assertQueryCondition(
        FlexMapEntity_.flexObject.equalsKeyValueDouble('key-double', 1234.56),
        box,
        [largeApple],
      );

      // Set key and value with a query parameter
      final query =
          box
              .query(FlexMapEntity_.flexObject.equalsKeyValueString('', ''))
              .build();
      query
          .param(FlexMapEntity_.flexObject)
          .twoValuesString('key-string', 'Apple');
      expect(query.findIds(), [largeApple]);
      query
          .param(FlexMapEntity_.flexObject)
          .twoValuesString('key-string', 'Cherry');
      expect(query.findIds(), [largeCherry]);
      query
          .param(FlexMapEntity_.flexObject)
          .twoValuesString('no-such-key', 'Apple');
      expect(query.findIds(), isEmpty);
      query.close();

      // Set key and value with a query parameter using an alias
      final aliasQuery =
          box
              .query(
                FlexMapEntity_.flexObject.equalsKeyValueString(
                  '',
                  '',
                  alias: 'kv',
                ),
              )
              .build();
      aliasQuery
          .param(FlexMapEntity_.flexObject, alias: 'kv')
          .twoValuesString('key-string', 'Apple');
      expect(aliasQuery.findIds(), [largeApple]);
      aliasQuery
          .param(FlexMapEntity_.flexObject, alias: 'kv')
          .twoValuesString('key-string', 'Cherry');
      expect(aliasQuery.findIds(), [largeCherry]);
      aliasQuery
          .param(FlexMapEntity_.flexObject, alias: 'kv')
          .twoValuesString('no-such-key', 'Apple');
      expect(aliasQuery.findIds(), isEmpty);
      // Change the condition to compare against int and double values
      aliasQuery
          .param(FlexMapEntity_.flexObject, alias: 'kv')
          .twoValuesInt('key-long', 3);
      expect(aliasQuery.findIds(), [largeCherry]);
      aliasQuery
          .param(FlexMapEntity_.flexObject, alias: 'kv')
          .twoValuesDouble('key-double', 1234.56);
      expect(aliasQuery.findIds(), [largeApple]);
      aliasQuery.close();

      // Set key and int value with a query parameter
      final intQuery =
          box.query(FlexMapEntity_.flexObject.equalsKeyValueInt('', 0)).build();
      intQuery
          .param(FlexMapEntity_.flexObject)
          .twoValuesInt('key-long', 234234234);
      expect(intQuery.findIds(), [largeApple]);
      intQuery.param(FlexMapEntity_.flexObject).twoValuesInt('key-long', 3);
      expect(intQuery.findIds(), [largeCherry]);
      intQuery.param(FlexMapEntity_.flexObject).twoValuesInt('no-such-key', 3);
      expect(intQuery.findIds(), isEmpty);
      // Change the condition to compare against a string value
      intQuery
          .param(FlexMapEntity_.flexObject)
          .twoValuesString('key-string', 'Apple');
      expect(intQuery.findIds(), [largeApple]);
      intQuery.close();

      // Set key and double value with a query parameter
      final doubleQuery =
          box
              .query(FlexMapEntity_.flexObject.equalsKeyValueDouble('', 0.0))
              .build();
      doubleQuery
          .param(FlexMapEntity_.flexObject)
          .twoValuesDouble('key-double', 1234.56);
      expect(doubleQuery.findIds(), [largeApple]);
      doubleQuery
          .param(FlexMapEntity_.flexObject)
          .twoValuesDouble('key-double', -1234.56);
      expect(doubleQuery.findIds(), [largeCherry]);
      doubleQuery
          .param(FlexMapEntity_.flexObject)
          .twoValuesDouble('no-such-key', 1234.56);
      expect(doubleQuery.findIds(), isEmpty);
      // Change the condition to compare against an int value
      doubleQuery.param(FlexMapEntity_.flexObject).twoValuesInt('key-long', 3);
      expect(doubleQuery.findIds(), [largeCherry]);
      doubleQuery.close();
    });

    test('greaterKeyValue_stringObjectMap', () {
      final objects = createObjectsWithStringObjectMap();
      box.putMany(objects);
      final apple = objects[0].id;
      final largeCherry = objects[1].id;
      final largeApple = objects[2].id;
      final pineapple = objects[3].id;

      // Note: CASE_SENSITIVE orders like "Apple, Cherry, apple, pineapple"
      // CASE_SENSITIVE: greater than "Cherry" -> "apple", "pineapple"
      assertQueryCondition(
        FlexMapEntity_.flexDynamic.greaterKeyValueString(
          'key-string',
          'Cherry',
          caseSensitive: true,
        ),
        box,
        [apple, pineapple],
      );
      assertQueryCondition(
        FlexMapEntity_.flexObject.greaterKeyValueString(
          'key-string',
          'Cherry',
          caseSensitive: false,
        ),
        box,
        [pineapple],
      );
      assertQueryCondition(
        FlexMapEntity_.flexObjectNonNull.greaterKeyValueInt('key-long', -2),
        box,
        [apple, largeCherry, largeApple],
      );
      assertQueryCondition(
        FlexMapEntity_.flexNonNull.greaterKeyValueInt('key-long', 234234234),
        box,
        [],
      );
      assertQueryCondition(
        FlexMapEntity_.flexExplicit.greaterKeyValueDouble('key-double', 0.0),
        box,
        [largeApple, pineapple],
      );
      assertQueryCondition(
        FlexMapEntity_.flexDynamic.greaterKeyValueDouble('key-double', 1234.56),
        box,
        [],
      );
    });

    test('greaterEqualsKeyValue_stringObjectMap', () {
      final objects = createObjectsWithStringObjectMap();
      box.putMany(objects);
      final apple = objects[0].id;
      final largeCherry = objects[1].id;
      final largeApple = objects[2].id;
      final pineapple = objects[3].id;

      // Note: CASE_SENSITIVE orders like "Apple, Cherry, apple, pineapple"
      assertQueryCondition(
        FlexMapEntity_.flexObject.greaterOrEqualKeyValueString(
          'key-string',
          'Cherry',
          caseSensitive: true,
        ),
        box,
        [apple, largeCherry, pineapple],
      );
      assertQueryCondition(
        FlexMapEntity_.flexObjectNonNull.greaterOrEqualKeyValueString(
          'key-string',
          'Cherry',
          caseSensitive: false,
        ),
        box,
        [largeCherry, pineapple],
      );
      assertQueryCondition(
        FlexMapEntity_.flexNonNull.greaterOrEqualKeyValueInt('key-long', -2),
        box,
        [apple, largeCherry, largeApple],
      );
      assertQueryCondition(
        FlexMapEntity_.flexExplicit.greaterOrEqualKeyValueInt(
          'key-long',
          234234234,
        ),
        box,
        [largeApple],
      );
      assertQueryCondition(
        FlexMapEntity_.flexDynamic.greaterOrEqualKeyValueDouble(
          'key-double',
          0.05,
        ),
        box,
        [largeApple, pineapple],
      );
      assertQueryCondition(
        FlexMapEntity_.flexObject.greaterOrEqualKeyValueDouble(
          'key-double',
          1234.54,
        ),
        box,
        [largeApple],
      );
    });

    test('lessKeyValue_stringObjectMap', () {
      final objects = createObjectsWithStringObjectMap();
      box.putMany(objects);
      final apple = objects[0].id;
      final largeCherry = objects[1].id;
      final largeApple = objects[2].id;
      final pineapple = objects[3].id;

      // Note: CASE_SENSITIVE orders like "Apple, Cherry, apple, pineapple"
      assertQueryCondition(
        FlexMapEntity_.flexObjectNonNull.lessKeyValueString(
          'key-string',
          'Cherry',
          caseSensitive: true,
        ),
        box,
        [largeApple],
      );
      assertQueryCondition(
        FlexMapEntity_.flexNonNull.lessKeyValueString(
          'key-string',
          'Cherry',
          caseSensitive: false,
        ),
        box,
        [apple, largeApple],
      );
      assertQueryCondition(
        FlexMapEntity_.flexExplicit.lessKeyValueInt('key-long', -2),
        box,
        [pineapple],
      );
      assertQueryCondition(
        FlexMapEntity_.flexDynamic.lessKeyValueInt('key-long', 6734234234),
        box,
        [apple, largeCherry, largeApple, pineapple],
      );
      assertQueryCondition(
        FlexMapEntity_.flexObject.lessKeyValueDouble('key-double', 0.0),
        box,
        [apple, largeCherry],
      );
      assertQueryCondition(
        FlexMapEntity_.flexObjectNonNull.lessKeyValueDouble(
          'key-double',
          1234.56,
        ),
        box,
        [apple, largeCherry, pineapple],
      );
    });

    test('lessEqualsKeyValue_stringObjectMap', () {
      final objects = createObjectsWithStringObjectMap();
      box.putMany(objects);
      final apple = objects[0].id;
      final largeCherry = objects[1].id;
      final largeApple = objects[2].id;
      final pineapple = objects[3].id;

      // Note: CASE_SENSITIVE orders like "Apple, Cherry, apple, pineapple"
      assertQueryCondition(
        FlexMapEntity_.flexNonNull.lessOrEqualKeyValueString(
          'key-string',
          'Cherry',
          caseSensitive: true,
        ),
        box,
        [largeCherry, largeApple],
      );
      assertQueryCondition(
        FlexMapEntity_.flexExplicit.lessOrEqualKeyValueString(
          'key-string',
          'Cherry',
          caseSensitive: false,
        ),
        box,
        [apple, largeCherry, largeApple],
      );
      assertQueryCondition(
        FlexMapEntity_.flexDynamic.lessOrEqualKeyValueInt('key-long', -1),
        box,
        [apple, pineapple],
      );
      assertQueryCondition(
        FlexMapEntity_.flexObject.lessOrEqualKeyValueInt('key-long', -567),
        box,
        [pineapple],
      );
      assertQueryCondition(
        FlexMapEntity_.flexObjectNonNull.lessOrEqualKeyValueDouble(
          'key-double',
          0.0,
        ),
        box,
        [apple, largeCherry],
      );
      assertQueryCondition(
        FlexMapEntity_.flexNonNull.lessOrEqualKeyValueDouble(
          'key-double',
          1234.56,
        ),
        box,
        [apple, largeCherry, largeApple, pineapple],
      );
    });

    test('parameterized query', () {
      final entity1 = FlexMapEntity(flexDynamic: {'key1': 'value1'});
      final entity2 = FlexMapEntity(flexDynamic: {'key2': 'value2'});
      box.putMany([entity1, entity2]);

      final query =
          box.query(FlexMapEntity_.flexDynamic.containsElement('')).build();
      query.param(FlexMapEntity_.flexDynamic).valueString = 'key1';
      final results = query.findIds();
      expect(results, [entity1.id]);

      query.param(FlexMapEntity_.flexDynamic).valueString = 'value3';
      final results2 = query.findIds();
      expect(results2, isEmpty);

      query.close();
    });
  });

  group('Flex List property (List<dynamic>)', () {
    late Box<FlexListEntity> box;

    setUp(() {
      box = store.box<FlexListEntity>();
    });

    test('put and get with null values', () {
      final entity = FlexListEntity();
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexDynamic, isNull);
      expect(read.flexObject, isNull);
      expect(read.flexNonNull, isEmpty);
      expect(read.flexListOfMaps, isNull);
      expect(read.flexExplicit, isNull);
    });

    test('put and get list with various value types', () {
      final testList = ['Alice', 30, 3.14, true];
      final testListWithNull = List<Object?>.from(testList) + [null];
      final entity = FlexListEntity(
        flexDynamic: testListWithNull,
        flexObject: testListWithNull,
        flexObjectNonNull: testList,
        flexNonNull: testListWithNull,
        flexExplicit: testListWithNull,
      );
      final id = box.put(entity);

      assertTestList(List<dynamic> list) {
        expect(list[0], 'Alice');
        expect(list[1], 30);
        expect(list[2], 3.14);
        expect(list[3], true);
      }

      assertTestListWithNull(List<dynamic> list) {
        assertTestList(list);
        expect(list[4], isNull);
      }

      final read = box.get(id)!;
      assertTestListWithNull(read.flexDynamic!);
      assertTestListWithNull(read.flexObject!);
      assertTestList(read.flexObjectNonNull!);
      assertTestListWithNull(read.flexNonNull);
      assertTestListWithNull(read.flexExplicit!);
    });

    test('put and get nested list', () {
      final entity = FlexListEntity(
        flexDynamic: [
          [1, 2, 3],
          ['a', 'b', 'c'],
          [
            [true, false],
          ],
        ],
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexDynamic![0], [1, 2, 3]);
      expect(read.flexDynamic![1], ['a', 'b', 'c']);
      expect((read.flexDynamic![2] as List)[0], [true, false]);
    });

    test('put and get list with map values', () {
      final entity = FlexListEntity(
        flexDynamic: [
          {'name': 'Alice', 'age': 30},
          {'name': 'Bob', 'age': 25},
        ],
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      final first = read.flexDynamic![0] as Map<String, dynamic>;
      expect(first['name'], 'Alice');
      expect(first['age'], 30);
      final second = read.flexDynamic![1] as Map<String, dynamic>;
      expect(second['name'], 'Bob');
      expect(second['age'], 25);
    });

    test('put and get complex nested structure', () {
      final entity = FlexListEntity(
        flexDynamic: [
          {
            'users': [
              {'name': 'Alice'},
              {'name': 'Bob'},
            ],
          },
          [1, 2, 3],
          'string',
          42,
        ],
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      final firstMap = read.flexDynamic![0] as Map<String, dynamic>;
      final users = firstMap['users'] as List;
      expect((users[0] as Map)['name'], 'Alice');
      expect(read.flexDynamic![1], [1, 2, 3]);
      expect(read.flexDynamic![2], 'string');
      expect(read.flexDynamic![3], 42);
    });

    test('put and get list with nested map', () {
      var testList = [
        {'key1': 'value1', 'nullable': null},
        {
          'key2': 'value2',
          'nested': {'a': 1},
        },
      ];
      final entity = FlexListEntity(
        flexListOfMaps: testList,
        flexListOfMapsObject: testList,
      );
      final id = box.put(entity);

      assertNestedMap(List<Map<String, dynamic>> list) {
        expect(list.length, 2);
        final first = list[0];
        expect(first['key1'], 'value1');
        // Because the List element type of the properties is defined as
        // non-null, null values are skipped, which also affects nested maps
        // (and lists).
        expect(first.containsKey('nullable'), false);
        final second = list[1];
        expect(second['key2'], 'value2');
        expect((second['nested'] as Map)['a'], 1);
      }

      final read = box.get(id)!;
      assertNestedMap(read.flexListOfMaps!);
      assertNestedMap(read.flexListOfMapsObject!);
    });

    test('update list value', () {
      final entity = FlexListEntity(flexDynamic: [1, 2, 3]);
      final id = box.put(entity);

      // Update
      final read = box.get(id)!;
      read.flexDynamic = [4, 5, 6, 'updated'];
      box.put(read);

      // Verify update
      final updated = box.get(id)!;
      expect(updated.flexDynamic, [4, 5, 6, 'updated']);
    });

    test('set list to null', () {
      final entity = FlexListEntity(flexDynamic: ['data']);
      final id = box.put(entity);

      // Set to null
      final read = box.get(id)!;
      read.flexDynamic = null;
      box.put(read);

      // Verify null
      final updated = box.get(id)!;
      expect(updated.flexDynamic, isNull);
    });

    test('empty list is stored and retrieved correctly', () {
      final entity = FlexListEntity(flexDynamic: []);
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexDynamic, isNotNull);
      expect(read.flexDynamic, isEmpty);
    });

    test('putMany and getAll', () {
      final entities = [
        FlexListEntity(flexDynamic: [0, 'first']),
        FlexListEntity(flexDynamic: [1, 'second']),
        FlexListEntity(flexDynamic: [2, 'third']),
      ];
      box.putMany(entities);

      final all = box.getAll();
      expect(all.length, 3);
      for (var i = 0; i < 3; i++) {
        expect(all[i].flexDynamic![0], i);
      }
    });

    test('parameterized query', () {
      final entities = [
        FlexListEntity(flexDynamic: [0, 'first']),
        FlexListEntity(flexDynamic: [1, 'second']),
        FlexListEntity(flexDynamic: [2, 'third']),
      ];
      box.putMany(entities);

      final query =
          box.query(FlexListEntity_.flexDynamic.containsElement('')).build();
      query.param(FlexListEntity_.flexDynamic).value = 'first';
      final results = query.findIds();
      expect(results, [entities[0].id]);

      query.param(FlexListEntity_.flexDynamic).value = 'fifth';
      final results2 = query.findIds();
      expect(results2, isEmpty);

      query.param(FlexListEntity_.flexDynamic).value = '2';
      final results3 = query.findIds();
      expect(results3, [entities[2].id]);

      query.close();
    });

    FlexListEntity createObjectWithFlexList(String s, int i, double d) {
      final entity = FlexListEntity();
      final list = <Object>[s, i, d];
      entity.flexDynamic = list;
      entity.flexObject = list;
      entity.flexObjectNonNull = list;
      entity.flexNonNull = list;
      entity.flexListOfMaps = [
        {'key-string': s, 'key-int': i},
        {'key-int': i, 'key-double': d},
      ];
      entity.flexListOfMapsObject = [
        {'key-string': s, 'key-int': i},
        {'key-int': i, 'key-double': d},
      ];
      return entity;
    }

    test("containsElement_flexList", () {
      final objects = [
        createObjectWithFlexList('banana', 42, -0.5),
        createObjectWithFlexList('Banana', 0, 3.1415),
        createObjectWithFlexList('grape', 42, 2.718),
        createObjectWithFlexList('Banana', -1000, 0.0),
      ];
      box.putMany(objects);
      final obj1 = objects[0].id;
      final obj2 = objects[1].id;
      final obj3 = objects[2].id;
      final obj4 = objects[3].id;

      assertQueryCondition(
        FlexListEntity_.flexDynamic.containsElement('Banana'),
        box,
        [obj2, obj4],
      );
      assertQueryCondition(
        FlexListEntity_.flexObject.containsElement('banana'),
        box,
        [obj1],
      );
      assertQueryCondition(
        FlexListEntity_.flexObjectNonNull.containsElement('grape'),
        box,
        [obj3],
      );
      assertQueryCondition(
        FlexListEntity_.flexObject.containsElement('42'),
        box,
        [obj1, obj3],
      );
      assertQueryCondition(
        FlexListEntity_.flexObject.containsElement('-1000'),
        box,
        [obj4],
      );
    });
  });

  group('Flex Value property (dynamic/Object?)', () {
    late Box<FlexValueEntity> box;

    setUp(() {
      box = store.box<FlexValueEntity>();
    });

    test('put and get null values', () {
      final entity = FlexValueEntity();
      final id = box.put(entity);

      final read = box.get(id)!;
      // Auto-detected
      expect(read.flexDynamic, isNull);
      expect(read.flexObject, isNull);
      // Explicitly annotated
      expect(read.flexDynamicExplicit, isNull);
      expect(read.flexObjectExplicit, isNull);
    });

    test('put and get value with various types', () {
      assertPutAndGet<V>(V value) {
        final entity = FlexValueEntity(
          flexDynamic: value,
          flexObject: value,
          flexDynamicExplicit: value,
          flexObjectExplicit: value,
        );
        final id = box.put(entity);

        final read = box.get(id)!;
        // Auto-detected
        expect(read.flexDynamic, value);
        expect(read.flexObject, value);
        // Explicitly annotated
        expect(read.flexDynamicExplicit, value);
        expect(read.flexObjectExplicit, value);
      }

      assertPutAndGet('hello world');
      assertPutAndGet(42);
      assertPutAndGet(3.14159);
      assertPutAndGet(true);
      assertPutAndGet([1, 'two', 3.0]);
      assertPutAndGet({'key': 'value', 'number': 42, 'nullable': null});
    });

    test('update value type', () {
      // Start with a string
      final entity = FlexValueEntity(
        flexDynamic: 'initial',
        flexDynamicExplicit: 'initial',
      );
      final id = box.put(entity);

      // Update to an int
      final read = box.get(id)!;
      read.flexDynamic = 123;
      read.flexDynamicExplicit = 123;
      box.put(read);

      // Verify update
      final updated = box.get(id)!;
      expect(updated.flexDynamic, 123);
      expect(updated.flexDynamicExplicit, 123);

      // Update to a map
      updated.flexDynamic = {'changed': true};
      updated.flexDynamicExplicit = {'changed': true};
      box.put(updated);

      final final_ = box.get(id)!;
      expect((final_.flexDynamic as Map)['changed'], true);
      expect((final_.flexDynamicExplicit as Map)['changed'], true);
    });

    test('set value to null', () {
      final entity = FlexValueEntity(
        flexDynamic: 'not null',
        flexDynamicExplicit: 'not null',
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      read.flexDynamic = null;
      read.flexDynamicExplicit = null;
      box.put(read);

      final updated = box.get(id)!;
      expect(updated.flexDynamic, isNull);
      expect(updated.flexDynamicExplicit, isNull);
    });

    test('equalsValue', () {
      final entity1 = FlexValueEntity(flexDynamic: 'test', flexObject: 123);
      final entity2 = FlexValueEntity(flexDynamic: 'Test', flexObject: 456);
      box.putMany([entity1, entity2]);
      final id1 = entity1.id;
      final id2 = entity2.id;

      assertQueryCondition(FlexValueEntity_.flexDynamic.equals('test'), box, [
        id1,
      ]);

      assertQueryCondition(FlexValueEntity_.flexObject.equals('456'), box, [
        id2,
      ]);
    });

    test('parameterized query', () {
      final entity1 = FlexValueEntity(flexDynamic: 'first');
      final entity2 = FlexValueEntity(flexDynamic: 2);
      box.putMany([entity1, entity2]);

      final query = box.query(FlexValueEntity_.flexDynamic.equals('')).build();
      query.param(FlexValueEntity_.flexDynamic).value = 'first';
      final results = query.findIds();
      expect(results, [entity1.id]);

      query.param(FlexValueEntity_.flexDynamic).value = '2';
      final results2 = query.findIds();
      expect(results2, [entity2.id]);

      query.close();
    });
  });
}
