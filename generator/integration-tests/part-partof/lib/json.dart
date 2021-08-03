import 'package:json_annotation/json_annotation.dart';
import 'package:objectbox/objectbox.dart';

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

@Entity()
@JsonSerializable()
class JsonPerson {
  int? id;
  String name;

  JsonPerson({required this.name});

  factory JsonPerson.fromJson(Map<String, dynamic> json) =>
      _$JsonPersonFromJson(json);

  Map<String, dynamic> toJson() => _$JsonPersonToJson(this);
}

@Entity()
@JsonSerializable()
class JsonBook {
  int? id;

  @_PersonRelToOneConverter()
  final ToOne<JsonPerson> author;

  JsonBook({required this.author});

  factory JsonBook.fromJson(Map<String, dynamic> json) => _$JsonBookFromJson(json);

  Map<String, dynamic> toJson() => _$JsonBookToJson(this);
}

class _PersonRelToOneConverter
    implements JsonConverter<ToOne<JsonPerson>, Map<String, dynamic>?> {
  const _PersonRelToOneConverter();

  @override
  ToOne<JsonPerson> fromJson(Map<String, dynamic>? json) => ToOne<JsonPerson>(
      target: json == null ? null : JsonPerson.fromJson(json));

  @override
  Map<String, dynamic>? toJson(ToOne<JsonPerson> rel) => rel.target?.toJson();
}
