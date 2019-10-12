import "package:objectbox/objectbox.dart";
import "package:objectbox/src/bindings/constants.dart";

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

@Entity()
class TestEntityProperty {

  @Id()
  int id;

  // See OB-C, objectbox.h
  bool tBool; // 1 byte
  int  tLong; // ob: 8 bytes, dart: 8 bytes
  double tDouble; // ob: 8 bytes, dart: 8 bytes
  String tString;

  @Property(type:2 /*OBXPropertyType.Byte*/)
  int tByte; // 1 byte

  @Property(type:3 /*OBXPropertyType.Short*/)
  int tShort; // 2 byte

  @Property(type:4 /*OBXPropertyType.Char*/)
  int tChar; // 1 byte

  @Property(type:5 /*OBXPropertyType.Int*/)
  int tInt; // ob: 4 bytes, dart: 8 bytes

  @Property(type:7 /*OBXPropertyType.Float*/)
  double tFloat; // 4 bytes
}
