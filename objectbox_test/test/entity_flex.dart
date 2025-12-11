import 'package:objectbox/objectbox.dart';

/// Entity to test Flex Map properties (`Map<String, dynamic>` stored as FlexBuffers)
@Entity()
class FlexMapEntity {
  @Id()
  int id = 0;

  // Auto-detected Map<String, dynamic> - nullable
  Map<String, dynamic>? flexDynamic;

  // Auto-detected Map<String, Object?> - nullable
  Map<String, Object?>? flexObject;

  // Non-nullable with default empty map
  Map<String, dynamic> flexNonNull = {};

  // Explicit annotation
  @Property(type: PropertyType.flex)
  Map<String, dynamic>? flexExplicit;

  FlexMapEntity({
    this.flexDynamic,
    this.flexObject,
    this.flexNonNull = const {},
    this.flexExplicit,
  });
}

/// Entity to test Flex List properties (`List<dynamic>` stored as FlexBuffers)
@Entity()
class FlexListEntity {
  @Id()
  int id = 0;

  // Auto-detected List<dynamic> - nullable
  List<dynamic>? flexDynamic;

  // Auto-detected List<Object?> - nullable
  List<Object?>? flexObject;

  // Auto-detected List<Object> (non-nullable elements) - nullable
  List<Object>? flexObjectNonNull;

  // Non-nullable with default empty list
  List<dynamic> flexNonNull = [];

  // Auto-detected List<Map<String, dynamic>> - nullable
  List<Map<String, dynamic>>? flexListOfMaps;

  // Auto-detected List<Map<String, Object?>> - nullable
  List<Map<String, Object?>>? flexListOfMapsObject;

  // Explicit annotation
  @Property(type: PropertyType.flex)
  List<dynamic>? flexExplicit;

  FlexListEntity({
    this.flexDynamic,
    this.flexObject,
    this.flexObjectNonNull,
    this.flexNonNull = const [],
    this.flexListOfMaps,
    this.flexListOfMapsObject,
    this.flexExplicit,
  });
}
