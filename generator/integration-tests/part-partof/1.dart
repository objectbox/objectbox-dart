import 'dart:io';

import 'package:test/test.dart';

import '../common.dart';
import '../test_env.dart';
import 'lib/frozen.dart';
import 'lib/json.dart';
import 'lib/objectbox.g.dart';

void main() {
  commonModelTests(getObjectBoxModel(), readModelJson('lib'));

  test('project must be generated properly', () {
    expect(File('lib/objectbox.g.dart').existsSync(), true);
    expect(File('lib/objectbox-model.json').existsSync(), true);
  });

  group('package:JsonSerializable', () {
    setupTestsFor(JsonEntity(id: 0, str: 'foo', date: DateTime.now()));
    setupRelTestsFor(JsonBook.fromJson({
      'author': {'name': 'Charles'},
      'readers': [
        {'name': 'Emily'},
        {'name': 'Diana'}
      ]
    }));
  });

  group('package:Freezed', () {
    setupTestsFor(FrozenEntity(id: 1, str: 'foo', date: DateTime.now()));
    final author = FrozenPerson(id: 1, name: 'Charles');
    final readers = [
      FrozenPerson(id: 2, name: 'Emily'),
      FrozenPerson(id: 3, name: 'Diana')
    ];
    setupRelTestsFor(
        FrozenBook(
            id: 1,
            author: ToOne(target: author),
            readers: ToMany(items: readers)),
        (Store store) =>
            store.box<FrozenPerson>().putMany([author, ...readers]));
  });
}

void setupTestsFor<EntityT>(EntityT newObject) {
  group(EntityT.toString(), () {
    late TestEnv<EntityT> env;
    setUp(() => env = TestEnv(getObjectBoxModel()));
    tearDown(() => env.close());

    test('read/write', () {
      env.box.put(newObject);
      env.box.get(1);
    });
  });
}

void setupRelTestsFor<BookEntityT>(BookEntityT book,
    [void Function(Store)? init]) {
  group(BookEntityT.toString(), () {
    late TestEnv<BookEntityT> env;
    setUp(() => env = TestEnv(getObjectBoxModel()));
    tearDown(() => env.close());

    test('relations', () {
      if (init != null) init(env.store);
      env.box.put(book);

      final bookRead = env.box.get(1)! as dynamic;
      expect(bookRead.author.targetId, 1);
      expect(bookRead.author.target!.name, 'Charles');

      expect(bookRead.readers[0]!.name, 'Emily');
      expect(bookRead.readers[1]!.name, 'Diana');
    });
  });
}
