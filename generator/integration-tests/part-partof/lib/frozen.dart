import 'package:objectbox/objectbox.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'frozen.freezed.dart';

@freezed
class FrozenEntity with _$FrozenEntity {
  @Entity(realClass: FrozenEntity)
  factory FrozenEntity(
      {@Id(assignable: true) required int id,
      required String str,
      required DateTime date}) = _FrozenEntity;
}
