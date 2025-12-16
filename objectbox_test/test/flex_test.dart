import 'package:objectbox/objectbox.dart';
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
        'null': null,
      };
      final entity = FlexMapEntity(
          flexDynamic: testMap,
          flexObject: testMap,
          flexNonNull: testMap,
          flexExplicit: testMap);
      final id = box.put(entity);

      assertTestMap(Map<String, dynamic> map) {
        expect(map['string'], 'hello');
        expect(map['int'], 42);
        expect(map['double'], 3.14);
        expect(map['bool'], false);
        expect(map['null'], isNull);
      }

      final read = box.get(id)!;
      assertTestMap(read.flexDynamic!);
      assertTestMap(read.flexObject!);
      assertTestMap(read.flexNonNull);
      assertTestMap(read.flexExplicit!);
    });

    test('put and get nested map', () {
      final entity = FlexMapEntity(
        flexDynamic: {
          'user': {
            'name': 'Bob',
            'address': {
              'city': 'Berlin',
              'zip': '10115',
            },
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
              'roles': ['admin', 'user']
            },
            {
              'name': 'Bob',
              'roles': ['user']
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
          flexExplicit: testListWithNull);
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
            [true, false]
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
            ]
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
          'nested': {'a': 1}
        },
      ];
      final entity = FlexListEntity(
          flexListOfMaps: testList, flexListOfMapsObject: testList);
      final id = box.put(entity);

      assertNestedMap(List<Map<String, dynamic>> list) {
        expect(list.length, 2);
        final first = list[0];
        expect(first['key1'], 'value1');
        expect(first['nullable'], isNull);
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
      expect(read.flexDynamic, isNull);
      expect(read.flexObject, isNull);
    });

    test('put and get string value', () {
      final entity = FlexValueEntity(flexDynamic: 'hello world');
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexDynamic, 'hello world');
    });

    test('put and get int value', () {
      final entity = FlexValueEntity(flexDynamic: 42);
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexDynamic, 42);
    });

    test('put and get double value', () {
      final entity = FlexValueEntity(flexDynamic: 3.14159);
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexDynamic, closeTo(3.14159, 0.00001));
    });

    test('put and get bool value', () {
      final entity = FlexValueEntity(flexDynamic: true);
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexDynamic, true);
    });

    test('put and get list value', () {
      final entity = FlexValueEntity(flexDynamic: [1, 'two', 3.0]);
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexDynamic, isA<List>());
      expect((read.flexDynamic as List)[0], 1);
      expect((read.flexDynamic as List)[1], 'two');
      expect((read.flexDynamic as List)[2], 3.0);
    });

    test('put and get map value', () {
      final entity = FlexValueEntity(
        flexDynamic: {'key': 'value', 'number': 42},
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexDynamic, isA<Map>());
      expect((read.flexDynamic as Map)['key'], 'value');
      expect((read.flexDynamic as Map)['number'], 42);
    });

    test('Object? works the same as dynamic', () {
      final entity = FlexValueEntity(flexObject: 'test string');
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexObject, 'test string');
    });

    test('update value type', () {
      // Start with a string
      final entity = FlexValueEntity(flexDynamic: 'initial');
      final id = box.put(entity);

      // Update to an int
      final read = box.get(id)!;
      read.flexDynamic = 123;
      box.put(read);

      // Verify update
      final updated = box.get(id)!;
      expect(updated.flexDynamic, 123);

      // Update to a map
      updated.flexDynamic = {'changed': true};
      box.put(updated);

      final final_ = box.get(id)!;
      expect((final_.flexDynamic as Map)['changed'], true);
    });

    test('set value to null', () {
      final entity = FlexValueEntity(flexDynamic: 'not null');
      final id = box.put(entity);

      final read = box.get(id)!;
      read.flexDynamic = null;
      box.put(read);

      final updated = box.get(id)!;
      expect(updated.flexDynamic, isNull);
    });
  });
}
