import 'package:objectbox/objectbox.dart';

@Entity()
class TestEntity {
  @Id()
  int /*?*/ id;

  String /*?*/ tString;

  @Property(type: PropertyType.int)
  int /*?*/ tInt; // 32-bit

  int /*?*/ tLong; // 64-bit

  double /*?*/ tDouble;

  TestEntity();

  TestEntity.full(this.tString, this.tInt, this.tLong, this.tDouble);
}
