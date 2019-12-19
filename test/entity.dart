import "package:objectbox/objectbox.dart";

/// A dummy annotation to verify the code is generated properly even with annotations unknown to ObjectBox generator.
class TestingUnknownAnnotation {
  const TestingUnknownAnnotation();
}

@Entity()
@TestingUnknownAnnotation()
class TestEntity {
  @Id()
  @TestingUnknownAnnotation()
  int id;

  // implicitly determined types
  String tString;
  int tLong;
  double tDouble;
  bool tBool;

  // explicitly declared types, see OB-C, objectbox.h

  // OBXPropertyType.Byte | 1 byte
  @Property(type: 2)
  int tByte;

  // OBXPropertyType.Short | 2 bytes
  @Property(type: 3)
  int tShort;

  // OBXPropertyType.Char | 1 byte
  @Property(type: 4)
  int tChar;

  // OBXPropertyType.Int |  ob: 4 bytes, dart: 8 bytes
  @Property(type: 5)
  int tInt;

  // OBXPropertyType.Float | 4 bytes
  @Property(type: 7)
  double tFloat;

  TestEntity(
      {this.id,
      this.tString,
      this.tLong,
      this.tDouble,
      this.tBool,
      this.tByte,
      this.tShort,
      this.tChar,
      this.tInt,
      this.tFloat});
}
