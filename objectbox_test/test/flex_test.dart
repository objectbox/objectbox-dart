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

    test('put and get with null values', () {
      final entity = FlexMapEntity();
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexDynamic, isNull);
      expect(read.flexObject, isNull);
      expect(read.flexNonNull, isEmpty);
      expect(read.flexExplicit, isNull);
    });

    test('put and get simple map', () {
      final entity = FlexMapEntity(
        flexDynamic: {'name': 'Alice', 'age': 30, 'active': true},
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexDynamic, isNotNull);
      expect(read.flexDynamic!['name'], 'Alice');
      expect(read.flexDynamic!['age'], 30);
      expect(read.flexDynamic!['active'], true);
    });

    test('put and get map with various value types', () {
      final entity = FlexMapEntity(
        flexDynamic: {
          'string': 'hello',
          'int': 42,
          'double': 3.14,
          'bool': false,
          'null': null,
        },
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexDynamic!['string'], 'hello');
      expect(read.flexDynamic!['int'], 42);
      expect(read.flexDynamic!['double'], closeTo(3.14, 0.001));
      expect(read.flexDynamic!['bool'], false);
      expect(read.flexDynamic!['null'], isNull);
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

    test('Map<String, Object?> works the same as Map<String, dynamic>', () {
      final entity = FlexMapEntity(
        flexObject: {'key': 'value', 'number': 123},
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexObject!['key'], 'value');
      expect(read.flexObject!['number'], 123);
    });

    test('non-nullable map defaults to empty map', () {
      final entity = FlexMapEntity();
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexNonNull, isA<Map<String, dynamic>>());
      expect(read.flexNonNull, isEmpty);
    });

    test('non-nullable map stores and retrieves data', () {
      final entity = FlexMapEntity(flexNonNull: {'key': 'value'});
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexNonNull['key'], 'value');
    });

    test('explicit @Property annotation works', () {
      final entity = FlexMapEntity(
        flexExplicit: {'explicit': true},
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexExplicit!['explicit'], true);
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

    test('put and get simple list', () {
      final entity = FlexListEntity(
        flexDynamic: ['Alice', 30, true],
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexDynamic, isNotNull);
      expect(read.flexDynamic![0], 'Alice');
      expect(read.flexDynamic![1], 30);
      expect(read.flexDynamic![2], true);
    });

    test('put and get list with various value types', () {
      final entity = FlexListEntity(
        flexDynamic: ['hello', 42, 3.14, false, null],
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexDynamic![0], 'hello');
      expect(read.flexDynamic![1], 42);
      expect(read.flexDynamic![2], closeTo(3.14, 0.001));
      expect(read.flexDynamic![3], false);
      expect(read.flexDynamic![4], isNull);
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

    test('List<Object?> works the same as List<dynamic>', () {
      final entity = FlexListEntity(
        flexObject: ['value', 123, null],
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexObject![0], 'value');
      expect(read.flexObject![1], 123);
      expect(read.flexObject![2], isNull);
    });

    test('List<Object> (non-nullable elements) auto-detection works', () {
      final entity = FlexListEntity(
        flexObjectNonNull: ['value', 123, 3.14, true],
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexObjectNonNull, isNotNull);
      expect(read.flexObjectNonNull![0], 'value');
      expect(read.flexObjectNonNull![1], 123);
      expect(read.flexObjectNonNull![2], 3.14);
      expect(read.flexObjectNonNull![3], true);
    });

    test('non-nullable list defaults to empty list', () {
      final entity = FlexListEntity();
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexNonNull, isA<List<dynamic>>());
      expect(read.flexNonNull, isEmpty);
    });

    test('non-nullable list stores and retrieves data', () {
      final entity = FlexListEntity(flexNonNull: ['value', 42]);
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexNonNull[0], 'value');
      expect(read.flexNonNull[1], 42);
    });

    test('List<Map<String, dynamic>> auto-detection works', () {
      final entity = FlexListEntity(
        flexListOfMaps: [
          {'key1': 'value1'},
          {
            'key2': 'value2',
            'nested': {'a': 1}
          },
        ],
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexListOfMaps, isNotNull);
      expect(read.flexListOfMaps!.length, 2);
      // Note: After deserialization, maps are Map<String, dynamic>
      final first = read.flexListOfMaps![0];
      expect(first['key1'], 'value1');
      final second = read.flexListOfMaps![1];
      expect(second['key2'], 'value2');
      expect((second['nested'] as Map)['a'], 1);
    });

    test('explicit @Property annotation works', () {
      final entity = FlexListEntity(
        flexExplicit: [true, 'explicit'],
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexExplicit![0], true);
      expect(read.flexExplicit![1], 'explicit');
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
}
