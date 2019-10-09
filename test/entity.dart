import "package:objectbox/objectbox.dart";
part "entity.g.dart";

@Entity()
class TestEntity {
  @Id()
  int id;

  String text;
  int number;
  double d;
  bool b;

  TestEntity();

  TestEntity.initId(this.id, this.text);
  TestEntity.initInteger(this.number);
  TestEntity.initIntegerAndText(this.number, this.text);
  TestEntity.initText(this.text);
  TestEntity.initDoubleAndBoolean(this.d, this.b);
}
