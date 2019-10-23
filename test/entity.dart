import "package:objectbox/objectbox.dart";
part 'entity.g.dart';

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

  // See ObjectBox-C, objectbox.h
  // https://github.com/objectbox/objectbox-c/blob/master/include/objectbox.h#L177-L191
  bool tBool; // 1 byte
  int tLong; // ob: 8 bytes, dart: 8 bytes
  double tDouble; // ob: 8 bytes, dart: 8 bytes
  String tString;

  @Property(type: 2 /*OBXPropertyType.Byte*/)
  int tByte; // 1 byte

  @Property(type: 3 /*OBXPropertyType.Short*/)
  int tShort; // 2 byte

  @Property(type: 4 /*OBXPropertyType.Char*/)
  int tChar; // 1 byte

  @Property(type: 5 /*OBXPropertyType.Int*/)
  int tInt; // ob: 4 bytes, dart: 8 bytes

  @Property(type: 7 /*OBXPropertyType.Float*/)
  double tFloat; // 4 bytes

  // TODO Throw a warning from the generator
  // TODO if the default ctor with no args is missing
  // TODO because OBX_Defs in the g.dart will blow up
  TestEntityProperty();

  TestEntityProperty.initIntegers(this.tBool, this.tByte, this.tChar, this.tShort, this.tInt, this.tLong);
  TestEntityProperty.initFloats(this.tDouble, this.tFloat);
  TestEntityProperty.initString(this.tString);
}
