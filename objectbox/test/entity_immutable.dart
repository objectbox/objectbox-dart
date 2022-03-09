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

  const TestEntityImmutable({
    this.id,
    required this.unique,
    required this.payload,
  });

  TestEntityImmutable copyWithId(int newId) =>
      (id != newId) ? copyWith(id: newId) : this;
}
