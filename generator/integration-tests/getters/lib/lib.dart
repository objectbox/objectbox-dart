import 'package:objectbox/objectbox.dart';

/// Test annotations on getters are applied to properties when using
/// getter + setter combos to create synthetic fields.
@Entity()
class AnnotatedGetters {
  int _dummyId = 0;

  // ID via annotation (not using auto-detected name id)
  @Id()
  int get customId => _dummyId;

  set customId(int value) {
    _dummyId = value;
  }

  int? _dummyProp;

  // Customizing property via annotation
  @Property(type: PropertyType.int)
  @Index()
  int? get prop => _dummyProp;

  set prop(int? value) => _dummyProp = value;

  // Ignore property via annotation
  @Transient()
  String? get ignored => "";

  set ignored(String? value) {}
}
