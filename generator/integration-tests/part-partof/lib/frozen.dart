import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:objectbox/objectbox.dart';

part 'frozen.freezed.dart';

@freezed
sealed class FrozenEntity with _$FrozenEntity {
  @Entity(realClass: FrozenEntity)
  factory FrozenEntity({
    @Id(assignable: true) required int id,
    required String str,
    required DateTime date,
  }) = _FrozenEntity;
}

@freezed
sealed class FrozenPerson with _$FrozenPerson {
  @Entity(realClass: FrozenPerson)
  factory FrozenPerson({
    @Id(assignable: true) required int id,
    required String name,
  }) = _FrozenPerson;
}

@freezed
sealed class FrozenBook with _$FrozenBook {
  @Entity(realClass: FrozenBook)
  factory FrozenBook({
    @Id(assignable: true) required int id,
    required ToOne<FrozenPerson> author,
    required ToMany<FrozenPerson> readers,
  }) = _FrozenBook;
}
