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
      'author': {'name': 'Charles'}
    }));
  });

  group('package:Freezed', () {
    setupTestsFor(FrozenEntity(id: 1, str: 'foo', date: DateTime.now()));
    final author = FrozenPerson(id: 1, name: 'Charles');
    setupRelTestsFor(
        FrozenBook(id: 1, author: ToOne<FrozenPerson>(target: author)), author);
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

void setupRelTestsFor<BookEntityT, PersonEntityT>(BookEntityT book,
    [PersonEntityT? author]) {
  group(BookEntityT.toString(), () {
    late TestEnv<BookEntityT> env;
    setUp(() => env = TestEnv(getObjectBoxModel()));
    tearDown(() => env.close());

    test('relations', () {
      if (author != null) {
        env.store.box<PersonEntityT>().put(author);
        (book as dynamic).author.target = author;
      }
      env.box.put(book);

      final bookRead = env.box.get(1)! as dynamic;
      expect(bookRead.author.targetId, 1);
      expect(bookRead.author.target!.name, 'Charles');
    });
  });
}
