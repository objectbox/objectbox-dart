@TestOn('browser')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:web_test/models.dart';
import 'package:web_test/objectbox.g.dart';

var _dbCounter = 0;

void main() {
  group('in-memory engine', () {
    late Store store;
    late Box<Person> box;
    late Box<House> houses;

    setUp(() async {
      store = openStore(directory: 'memory:t${_dbCounter++}');
      await store.ready;
      box = store.box<Person>();
      houses = store.box<House>();
    });

    tearDown(() => store.close());

    test('put/get roundtrip preserves all property types', () {
      final person = Person(
          name: 'Ada',
          email: 'ada@web.dev',
          age: 36,
          height: 1.7025,
          active: true,
          birthday: DateTime.fromMillisecondsSinceEpoch(478915200000),
          tags: ['math', 'web'],
          embedding: [1, 2, 3]);
      final id = box.put(person);
      expect(id, 1);
      expect(person.id, 1);

      final read = box.get(1)!;
      expect(read.name, 'Ada');
      expect(read.email, 'ada@web.dev');
      expect(read.age, 36);
      expect(read.height, 1.7025);
      expect(read.active, isTrue);
      expect(read.birthday!.millisecondsSinceEpoch, 478915200000);
      expect(read.tags, ['math', 'web']);
      expect(read.embedding, [1.0, 2.0, 3.0]);
    });

    test('ids are assigned sequentially and survive updates', () {
      final a = box.put(Person(name: 'a'));
      final b = box.put(Person(name: 'b'));
      expect([a, b], [1, 2]);
      final bObj = box.get(b)!..name = 'b2';
      expect(box.put(bObj), b);
      expect(box.get(b)!.name, 'b2');
      expect(box.put(Person(name: 'c')), 3);
    });

    test('PutMode insert/update are enforced', () {
      final id = box.put(Person(name: 'x'));
      expect(
          () => box.put(box.get(id)!, mode: PutMode.insert), throwsA(anything));
      final fresh = Person(name: 'y')..id = 999;
      expect(() => box.put(fresh, mode: PutMode.update), throwsA(anything));
      expect(box.count(), 1);
    });

    test('unique constraint is enforced', () {
      box.put(Person(name: 'a', email: 'same@x.io'));
      expect(() => box.put(Person(name: 'b', email: 'same@x.io')),
          throwsA(predicate((e) => '$e'.contains('Unique'))));
      // updating the same object keeps its unique value
      final a = box.getAll().first..name = 'a2';
      expect(() => box.put(a), returnsNormally);
      // after removal the value is free again
      box.remove(a.id);
      expect(() => box.put(Person(name: 'c', email: 'same@x.io')),
          returnsNormally);
    });

    test('getAll/count/contains/remove family', () {
      final ids = box.putMany(
          [Person(name: 'a'), Person(name: 'b'), Person(name: 'c')]);
      expect(ids, [1, 2, 3]);
      expect(box.count(), 3);
      expect(box.count(limit: 2), 2);
      expect(box.isEmpty(), isFalse);
      expect(box.contains(2), isTrue);
      expect(box.containsMany([1, 3]), isTrue);
      expect(box.containsMany([1, 4]), isFalse);
      expect(box.getAll().map((p) => p.name), ['a', 'b', 'c']);
      expect(box.getMany([3, 99, 1]).map((p) => p?.name), ['c', null, 'a']);
      expect(box.remove(2), isTrue);
      expect(box.remove(2), isFalse);
      expect(box.removeMany([1, 99]), 1);
      expect(box.removeAll(), 1);
      expect(box.isEmpty(), isTrue);
      // ids are not reused after removal
      expect(box.put(Person(name: 'd')), 4);
    });

    test('async variants work', () async {
      final id = await box.putAsync(Person(name: 'async'));
      expect((await box.getAsync(id))!.name, 'async');
      expect((await box.getAllAsync()).length, 1);
      expect(await box.removeAsync(id), isTrue);
    });

    test('ToOne target is put automatically and lazily loaded', () {
      final person = Person(name: 'resident');
      person.home.target = House('Web St. 185');
      box.put(person);
      expect(person.home.targetId, 1);
      expect(houses.count(), 1);

      final read = box.get(person.id)!;
      expect(read.home.target!.address, 'Web St. 185');
    });

    test('ToOne backlink resolves', () {
      final house = House('Backlink Ave.');
      final p1 = Person(name: 'p1')..home.target = house;
      box.put(p1);
      final p2 = Person(name: 'p2')..home.targetId = house.id;
      box.put(p2);

      final read = houses.get(house.id)!;
      expect(read.residents.map((p) => p.name).toSet(), {'p1', 'p2'});
    });

    test('ToMany relation put, read and remove', () {
      final a = Person(name: 'a');
      final b = Person(name: 'b');
      final c = Person(name: 'c');
      box.putMany([b, c]);
      a.friends.addAll([b, c]);
      box.put(a);

      var read = box.get(a.id)!;
      expect(read.friends.map((p) => p.name).toSet(), {'b', 'c'});

      read.friends.removeWhere((p) => p.name == 'b');
      read.friends.applyToDb();
      read = box.get(a.id)!;
      expect(read.friends.map((p) => p.name).toSet(), {'c'});

      // removing the target cleans up the relation
      box.remove(c.id);
      read = box.get(a.id)!;
      expect(read.friends, isEmpty);
    });

    test('runInTransaction rolls back on error', () {
      box.put(Person(name: 'keep', email: 'keep@x.io'));
      expect(
          () => store.runInTransaction(TxMode.write, () {
                box.put(Person(name: 'gone1'));
                box.put(Person(name: 'gone2'));
                throw StateError('boom');
              }),
          throwsStateError);
      expect(box.count(), 1);
      expect(box.getAll().single.name, 'keep');
      // the id sequence was rolled back too
      expect(box.put(Person(name: 'next')), 2);
    });

    test('failed put inside relations transaction rolls back cleanly', () {
      box.put(Person(name: 'a', email: 'dup@x.io'));
      final person = Person(name: 'b', email: 'dup@x.io');
      person.home.target = House('never stored');
      expect(() => box.put(person), throwsA(anything));
      // the house put through the ToOne was rolled back with the transaction
      expect(houses.isEmpty(), isTrue);
      expect(box.count(), 1);
    });

    test('watch and entityChanges emit on commit', () async {
      final events = <List<Type>>[];
      final sub = store.entityChanges.listen(events.add);
      final personEvents = <void>[];
      final sub2 = store.watch<Person>().listen(personEvents.add);

      box.put(Person(name: 'w'));
      houses.put(House('h'));
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 2);
      expect(events[0], [Person]);
      expect(events[1], [House]);
      expect(personEvents.length, 1);
      await sub.cancel();
      await sub2.cancel();
    });

    test('store registry: double open throws, attach shares data', () {
      expect(() => openStore(directory: store.directoryPath),
          throwsA(predicate((e) => '$e'.contains('still open'))));
      expect(Store.isOpen(store.directoryPath), isTrue);
      final attached =
          Store.attach(getObjectBoxModel(), store.directoryPath);
      box.put(Person(name: 'shared'));
      expect(attached.box<Person>().count(), 1);
      attached.close();
      // closing the attached handle must not close the underlying engine
      expect(box.count(), 1);
    });
  });

  group('IndexedDB persistence', () {
    test('data, relations and id sequence survive close and reopen', () async {
      final dir = 'idb-test-${DateTime.now().millisecondsSinceEpoch}';

      var store = openStore(directory: dir);
      await store.ready;
      var box = store.box<Person>();
      final ada = Person(
          name: 'Ada', email: 'ada@x.io', tags: ['persisted'], age: 36);
      ada.home.target = House('IDB Lane 1');
      final friend = Person(name: 'Friend');
      box.put(friend);
      ada.friends.add(friend);
      box.put(ada);
      box.remove(box.put(Person(name: 'temp'))); // consume an id
      store.close();

      store = openStore(directory: dir);
      await store.ready;
      box = store.box<Person>();
      expect(box.count(), 2);
      final readAda =
          box.getAll().singleWhere((person) => person.name == 'Ada');
      expect(readAda.email, 'ada@x.io');
      expect(readAda.tags, ['persisted']);
      expect(readAda.home.target!.address, 'IDB Lane 1');
      expect(readAda.friends.map((p) => p.name), ['Friend']);
      // unique index was rebuilt from persisted data
      expect(() => box.put(Person(name: 'clone', email: 'ada@x.io')),
          throwsA(predicate((e) => '$e'.contains('Unique'))));
      // the id sequence continues after the consumed id
      expect(box.put(Person(name: 'new')), 4);

      store.close();
      // allow the connection to close, then clean up
      await Future<void>.delayed(const Duration(milliseconds: 50));
      Store.removeDbFiles(dir);
    });
  });
}
