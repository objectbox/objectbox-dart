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
  late Box<FlexEntity> box;

  setUp(() {
    env = TestEnv('flex');
    store = env.store;
    box = store.box<FlexEntity>();
  });

  tearDown(() => env.closeAndDelete());

  group('Flex property (Map<String, dynamic>)', () {
    test('put and get with null values', () {
      final entity = FlexEntity();
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexDynamic, isNull);
      expect(read.flexObject, isNull);
      expect(read.flexNonNull, isEmpty);
      expect(read.flexExplicit, isNull);
    });

    test('put and get simple map', () {
      final entity = FlexEntity(
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
      final entity = FlexEntity(
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
      final entity = FlexEntity(
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
      final entity = FlexEntity(
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
      final entity = FlexEntity(
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
      final entity = FlexEntity(
        flexObject: {'key': 'value', 'number': 123},
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexObject!['key'], 'value');
      expect(read.flexObject!['number'], 123);
    });

    test('non-nullable map defaults to empty map', () {
      final entity = FlexEntity();
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexNonNull, isA<Map<String, dynamic>>());
      expect(read.flexNonNull, isEmpty);
    });

    test('non-nullable map stores and retrieves data', () {
      final entity = FlexEntity(flexNonNull: {'key': 'value'});
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexNonNull['key'], 'value');
    });

    test('explicit @Property annotation works', () {
      final entity = FlexEntity(
        flexExplicit: {'explicit': true},
      );
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexExplicit!['explicit'], true);
    });

    test('update map value', () {
      final entity = FlexEntity(flexDynamic: {'count': 1});
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
      final entity = FlexEntity(flexDynamic: {'data': 'exists'});
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
      final entity = FlexEntity(flexDynamic: {});
      final id = box.put(entity);

      final read = box.get(id)!;
      expect(read.flexDynamic, isNotNull);
      expect(read.flexDynamic, isEmpty);
    });

    test('putMany and getAll', () {
      final entities = [
        FlexEntity(flexDynamic: {'index': 0}),
        FlexEntity(flexDynamic: {'index': 1}),
        FlexEntity(flexDynamic: {'index': 2}),
      ];
      box.putMany(entities);

      final all = box.getAll();
      expect(all.length, 3);
      for (var i = 0; i < 3; i++) {
        expect(all[i].flexDynamic!['index'], i);
      }
    });
  });
}
