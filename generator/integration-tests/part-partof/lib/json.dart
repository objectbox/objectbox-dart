import 'package:objectbox/objectbox.dart';
import 'package:json_annotation/json_annotation.dart';

part 'json.g.dart';

@Entity()
@JsonSerializable()
class JsonEntity {
  int id;
  final String str;
  final DateTime? date;

  JsonEntity({required this.id, required this.str, required this.date});

  factory JsonEntity.fromJson(Map<String, dynamic> json) =>
      _$JsonEntityFromJson(json);

  Map<String, dynamic> toJson() => _$JsonEntityToJson(this);
}
