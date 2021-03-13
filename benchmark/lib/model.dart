import 'package:objectbox/objectbox.dart';

@Entity()
class TestEntity {
  @Id(assignable: true)
  int id;

  String tString;

  @Property(type: PropertyType.int)
  int tInt; // 32-bit

  int tLong; // 64-bit

  double tDouble;

  TestEntity(this.id, this.tString, this.tInt, this.tLong, this.tDouble);
}
