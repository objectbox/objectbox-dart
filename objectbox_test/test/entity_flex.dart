import 'package:objectbox/objectbox.dart';

/// Entity to test Flex properties (Map<String, dynamic> stored as FlexBuffers)
@Entity()
class FlexEntity {
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

  FlexEntity({
    this.flexDynamic,
    this.flexObject,
    this.flexNonNull = const {},
    this.flexExplicit,
  });
}
