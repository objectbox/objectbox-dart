import 'package:objectbox/objectbox.dart';

// Testing a model for immutable entities
@Entity()
class TestEntityImmutable {
  @Id(useCopyWith: true)
  final int? id;

  @Unique(onConflict: ConflictStrategy.replace)
  final int unique;

  final int payload;

  TestEntityImmutable copyWith({int? id, int? unique, int? payload}) =>
      TestEntityImmutable(
        id: id,
        unique: unique ?? this.unique,
        payload: payload ?? this.payload,
      );

  TestEntityImmutable({
    this.id,
    required this.unique,
    required this.payload,
  });

  TestEntityImmutable copyWithId(int newId) =>
      (id != newId) ? copyWith(id: newId) : this;
}

@Entity()
class TestEntityImmutableRel {
  @Id(useCopyWith: true)
  final int? id;

  final String? tString;

  TestEntityImmutableRel copyWith({int? id, String? tString}) =>
      TestEntityImmutableRel(
        id: id,
        tString: tString ?? this.tString,
      )
        ..relA.cloneFrom(relA)
        ..relB.cloneFrom(relB)
        ..relManyA.cloneFrom(relManyA);

  TestEntityImmutableRel({
    this.id,
    required this.tString,
  });

  TestEntityImmutableRel copyWithId(int newId) =>
      (id != newId) ? copyWith(id: newId) : this;

  final relA = ToOneProxy<RelatedImmutableEntityA>();
  final relB = ToOneProxy<RelatedImmutableEntityB>();

  final relManyA = ToManyProxy<RelatedImmutableEntityA>();
}

@Entity()
class RelatedImmutableEntityA {
  @Id(useCopyWith: true)
  final int? id;

  final int? tInt;
  final bool? tBool;
  final relB = ToOneProxy<RelatedImmutableEntityB>();

  @Backlink('relManyA')
  final testEntities = ToManyProxy<TestEntityImmutableRel>();

  RelatedImmutableEntityA({this.id, this.tInt, this.tBool});
  RelatedImmutableEntityA copyWithId(int newId) {
    if (newId == id) {
      return this;
    }
    return RelatedImmutableEntityA(
      id: newId,
      tInt: tInt,
      tBool: tBool,
    )
      ..relB.cloneFrom(relB)
      ..testEntities.cloneFrom(testEntities);
  }
}

@Entity()
class RelatedImmutableEntityB {
  @Id(useCopyWith: true)
  final int? id;

  final String? tString;
  final double? tDouble;
  final relA = ToOneProxy<RelatedImmutableEntityA>();
  final relB = ToOneProxy<RelatedImmutableEntityB>();

  @Backlink()
  final testEntities = ToManyProxy<TestEntityImmutableRel>();

  RelatedImmutableEntityB({this.id, this.tString, this.tDouble});
  RelatedImmutableEntityB copyWithId(int newId) {
    if (newId == id) {
      return this;
    }
    return RelatedImmutableEntityB(
      id: newId,
      tString: tString,
      tDouble: tDouble,
    )
      ..relA.cloneFrom(relA)
      ..relB.cloneFrom(relB)
      ..testEntities.cloneFrom(testEntities);
  }
}

@Entity()
class TreeNodeImmutable {
  @Id(useCopyWith: true)
  final int id;

  final String path; // just to help debugging, not used anywhere

  final parent = ToOneProxy<TreeNodeImmutable>();

  @Backlink()
  final children = ToManyProxy<TreeNodeImmutable>();

  TreeNodeImmutable(this.path, {this.id = 0});

  TreeNodeImmutable copyWithId(int newId) {
    if (id == newId) {
      return this;
    }

    return TreeNodeImmutable(path, id: newId)
      ..parent.cloneFrom(parent)
      ..children.cloneFrom(children);
  }
}
