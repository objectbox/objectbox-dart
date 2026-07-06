@TestOn('browser')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:web_test/models.dart';
import 'package:web_test/objectbox.g.dart';

var _dbCounter = 0;

void main() {
  late Store store;
  late Box<Person> box;
  late Box<House> houses;

  setUp(() async {
    store = openStore(directory: 'memory:q${_dbCounter++}');
    await store.ready;
    box = store.box<Person>();
    houses = store.box<House>();
    box.putMany([
      Person(name: 'Ada', email: 'ada@x.io', age: 36, height: 1.70),
      Person(name: 'Grace', email: 'grace@x.io', age: 85, height: 1.65),
      Person(name: 'alan', age: 41, height: 1.80, tags: ['logic', 'cs']),
      Person(
          name: 'Barbara',
          age: 36,
          height: 1.60,
          active: false,
          tags: ['cs'],
          birthday: DateTime.fromMillisecondsSinceEpoch(100000)),
    ]);
  });

  tearDown(() => store.close());

  List<String> names(Query<Person> q) =>
      q.find().map((p) => p.name).toList();

  test('string conditions with case sensitivity', () {
    expect(names(box.query(Person_.name.equals('Ada')).build()), ['Ada']);
    expect(names(box.query(Person_.name.equals('ada')).build()), isEmpty);
    expect(
        names(box
            .query(Person_.name.equals('ada', caseSensitive: false))
            .build()),
        ['Ada']);
    expect(
        names(box
            .query(Person_.name.startsWith('a', caseSensitive: false))
            .build()),
        ['Ada', 'alan']);
    expect(names(box.query(Person_.name.startsWith('a')).build()), ['alan']);
    expect(
        names(box
            .query(Person_.name.contains('ra', caseSensitive: true))
            .build()),
        ['Grace', 'Barbara']);
    expect(
        names(box.query(Person_.name.oneOf(['Ada', 'Grace'])).build()),
        ['Ada', 'Grace']);
    expect(names(box.query(Person_.name.notEquals('Ada')).build()),
        ['Grace', 'alan', 'Barbara']);
  });

  test('integer and double conditions', () {
    expect(names(box.query(Person_.age.equals(36)).build()),
        ['Ada', 'Barbara']);
    expect(names(box.query(Person_.age.between(40, 90)).build()),
        ['Grace', 'alan']);
    expect(names(box.query(Person_.age.oneOf([41, 85])).build()),
        ['Grace', 'alan']);
    expect(names(box.query(Person_.age.notOneOf([36])).build()),
        ['Grace', 'alan']);
    expect(names(box.query(Person_.age > 40).build()), ['Grace', 'alan']);
    expect(names(box.query(Person_.height.between(1.58, 1.66)).build()),
        ['Grace', 'Barbara']);
    expect(names(box.query(Person_.height.lessThan(1.66)).build()),
        ['Grace', 'Barbara']);
  });

  test('bool, date and null conditions', () {
    expect(names(box.query(Person_.active.equals(false)).build()),
        ['Barbara']);
    expect(names(box.query(Person_.email.isNull()).build()),
        ['alan', 'Barbara']);
    expect(names(box.query(Person_.email.notNull()).build()),
        ['Ada', 'Grace']);
    expect(
        names(box
            .query(Person_.birthday
                .equalsDate(DateTime.fromMillisecondsSinceEpoch(100000)))
            .build()),
        ['Barbara']);
    // null birthday never matches a value condition
    expect(
        names(box
            .query(Person_.birthday
                .lessThanDate(DateTime.fromMillisecondsSinceEpoch(1)))
            .build()),
        isEmpty);
  });

  test('string vector containsElement', () {
    expect(names(box.query(Person_.tags.containsElement('cs')).build()),
        ['alan', 'Barbara']);
    expect(names(box.query(Person_.tags.containsElement('logic')).build()),
        ['alan']);
  });

  test('and/or composition', () {
    expect(
        names(box
            .query(Person_.age.equals(36) & Person_.active.equals(true))
            .build()),
        ['Ada']);
    expect(
        names(box
            .query(Person_.name.equals('Ada') | Person_.name.equals('alan'))
            .build()),
        ['Ada', 'alan']);
    expect(
        names(box
            .query(Person_.age
                .equals(36)
                .andAll([Person_.active.equals(true)]).or(
                    Person_.name.equals('Grace')))
            .build()),
        ['Ada', 'Grace']);
  });

  test('order, offset, limit', () {
    var q = box.query().order(Person_.age).build();
    expect(names(q), ['Ada', 'Barbara', 'alan', 'Grace']);

    q = box.query().order(Person_.age, flags: Order.descending).build();
    expect(names(q), ['Grace', 'alan', 'Ada', 'Barbara']);

    // string order is case-insensitive by default
    q = box.query().order(Person_.name).build();
    expect(names(q), ['Ada', 'alan', 'Barbara', 'Grace']);
    q = box.query().order(Person_.name, flags: Order.caseSensitive).build();
    expect(names(q), ['Ada', 'Barbara', 'Grace', 'alan']);

    // nulls (email) first by default, last with nullsLast
    q = box.query().order(Person_.email).build();
    expect(names(q).sublist(0, 2), ['alan', 'Barbara']);
    q = box.query().order(Person_.email, flags: Order.nullsLast).build();
    expect(names(q).sublist(2), ['alan', 'Barbara']);

    final paged = box.query().order(Person_.age).build()
      ..offset = 1
      ..limit = 2;
    expect(names(paged), ['Barbara', 'alan']);
  });

  test('findFirst/findUnique/findIds/count/remove/stream', () async {
    expect(box.query(Person_.age.equals(36)).build().count(), 2);
    expect(
        box
            .query(Person_.name.equals('Ada'))
            .build()
            .findUnique()!
            .email,
        'ada@x.io');
    expect(() => box.query(Person_.age.equals(36)).build().findUnique(),
        throwsA(predicate((e) => '$e'.contains('more than one'))));
    expect(box.query(Person_.age.equals(36)).build().findFirst()!.name, 'Ada');
    expect(box.query(Person_.age.equals(36)).build().findIds(), [1, 4]);
    expect(await box.query(Person_.age.equals(36)).build().stream().length, 2);

    final removed = box.query(Person_.age.equals(36)).build().remove();
    expect(removed, 2);
    expect(box.count(), 2);
  });

  test('property queries: aggregate, distinct, find', () {
    final q = box.query().build();
    expect(q.property(Person_.age).min(), 36);
    expect(q.property(Person_.age).max(), 85);
    expect(q.property(Person_.age).sum(), 36 + 85 + 41 + 36);
    expect(q.property(Person_.age).average(), (36 + 85 + 41 + 36) / 4);
    expect(q.property(Person_.age).count(), 4);
    expect((q.property(Person_.age)..distinct = true).count(), 3);
    expect(q.property(Person_.name).find(),
        ['Ada', 'Grace', 'alan', 'Barbara']);
    // nulls are skipped, or replaced when requested
    expect(q.property(Person_.email).count(), 2);
    expect(q.property(Person_.email).find(replaceNullWith: '-'),
        ['ada@x.io', 'grace@x.io', '-', '-']);
    // property queries ignore offset/limit
    final limited = box.query().build()..limit = 1;
    expect(limited.property(Person_.age).count(), 4);
  });

  test('query parameters via property and alias', () {
    final q = box
        .query(Person_.name.equals('none', alias: 'n') &
            Person_.age.greaterThan(0))
        .build();
    expect(q.count(), 0);
    q.param(Person_.name, alias: 'n').value = 'Grace';
    expect(names(q), ['Grace']);
    q.param(Person_.age).value = 50;
    expect(names(q), ['Grace']);
    q.param(Person_.name, alias: 'n').value = 'Ada';
    expect(q.count(), 0); // Ada is not > 50
    expect(() => q.param(Person_.height), throwsArgumentError);
  });

  test('links: toOne, backlink, toMany, backlinkMany, relationCount', () {
    final h1 = House('Baker Street');
    final h2 = House('Main Road');
    final ada = box.get(1)!..home.target = h1;
    final grace = box.get(2)!..home.target = h2;
    box.putMany([ada, grace]);
    final alan = box.get(3)!;
    alan.friends.addAll([ada, grace]);
    box.put(alan);
    final barbara = box.get(4)!;
    barbara.friends.add(ada);
    box.put(barbara);

    // toOne link with condition on the target
    var q = (box.query()..link(Person_.home, House_.address.startsWith('Baker')))
        .build();
    expect(names(q), ['Ada']);

    // backlink: houses whose residents include someone aged > 50
    var hq =
        (houses.query()..backlink(Person_.home, Person_.age.greaterThan(50)))
            .build();
    expect(hq.find().map((h) => h.address), ['Main Road']);

    // toMany link: persons with a friend named Grace
    q = (box.query()..linkMany(Person_.friends, Person_.name.equals('Grace')))
        .build();
    expect(names(q), ['alan']);

    // backlinkMany: persons who are a friend of Barbara
    q = (box.query()
          ..backlinkMany(Person_.friends, Person_.name.equals('Barbara')))
        .build();
    expect(names(q), ['Ada']);

    // relationCount on the ToOne backlink: houses with exactly one resident
    hq = houses.query(House_.residents.relationCount(1)).build();
    expect(hq.find().map((h) => h.address).toSet(),
        {'Baker Street', 'Main Road'});
    hq = houses.query(House_.residents.relationCount(0)).build();
    expect(hq.count(), 0);
  });

  test('nearest neighbors (brute force) with scores', () {
    box.removeAll();
    box.putMany([
      Person(name: 'origin', embedding: [0, 0, 0]),
      Person(name: 'near', embedding: [0.1, 0, 0]),
      Person(name: 'far', embedding: [3, 4, 0]),
      Person(name: 'no-vector'),
    ]);

    final q = box
        .query(Person_.embedding.nearestNeighborsF32([0, 0, 0], 2))
        .build();
    expect(names(q), ['origin', 'near']);

    final scored = q.findWithScores();
    expect(scored.first.object.name, 'origin');
    expect(scored.first.score, 0);
    expect(scored[1].object.name, 'near');
    expect(scored[1].score, closeTo(0.01, 1e-9));

    final ids = q.findIdsWithScores();
    expect(ids.length, 2);
    expect(ids.first.score, 0);

    // combined with a filter condition
    final q2 = box
        .query(Person_.embedding.nearestNeighborsF32([0, 0, 0], 3) &
            Person_.name.notEquals('origin'))
        .build();
    expect(names(q2), ['near', 'far']);

    // scores require a nearest-neighbor query
    expect(() => box.query().build().findWithScores(), throwsStateError);

    // updating the query vector via param
    q.param(Person_.embedding).nearestNeighborsF32([3, 4, 0], 1);
    expect(names(q), ['far']);
  });

  test('watch emits on relevant changes', () async {
    final results = <int>[];
    final sub = box
        .query(Person_.age.greaterThan(50))
        .watch(triggerImmediately: true)
        .listen((query) => results.add(query.count()));
    await Future<void>.delayed(Duration.zero);
    expect(results, [1]); // Grace

    box.put(Person(name: 'Old', age: 99));
    await Future<void>.delayed(Duration.zero);
    expect(results, [1, 2]);

    houses.put(House('unrelated')); // different entity: no emission
    await Future<void>.delayed(Duration.zero);
    expect(results, [1, 2]);
    await sub.cancel();
  });

  test('describe', () {
    final q = box.query(Person_.age.equals(36)).build();
    expect(q.describe(), contains('Person'));
    expect(q.describeParameters(), contains('age'));
    expect(q.entityId, greaterThan(0));
    q.close();
  });
}
