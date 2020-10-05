import 'package:objectbox/objectbox.dart';
import 'package:objectbox/src/bindings/constants.dart';

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

  @Transient()
  int ignore;

  @Transient()
  int omit, disregard;

  // explicitly declared types, see OB-C, objectbox.h

  // OBXPropertyType.Byte | 1 byte
  @Property(type: OBXPropertyType.Byte)
  int tByte;

  // OBXPropertyType.Short | 2 bytes
  @Property(type: OBXPropertyType.Short)
  int tShort;

  // OBXPropertyType.Char | 1 byte
  @Property(type: OBXPropertyType.Char)
  int tChar;

  // OBXPropertyType.Int |  ob: 4 bytes, dart: 8 bytes
  @Property(type: OBXPropertyType.Int)
  int tInt;

  // OBXPropertyType.Float | 4 bytes
  @Property(type: OBXPropertyType.Float)
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
      this.tFloat,
      this.ignore});

  TestEntity.ignoredExcept(this.tInt) {
    omit = -1;
    disregard = 1;
  }

  @Unique(type:OBXPropertyType.Short)
  int uShort;

  @Unique(type:OBXPropertyType.Char)
  int uChar;

  @Unique(type:OBXPropertyType.Int)
  int uInt;

  // implicitly determined types
  @Unique()
  String uString;

  @Unique()
  int uLong;

  TestEntity.unique({
    this.uString,
    this.uLong,
    this.uInt,
    this.uShort,
    this.uChar,
  });

  @Index(type:OBXPropertyType.Short)
  int iShort;

  @Index(type:OBXPropertyType.Char)
  int iChar;

  @Index(type:OBXPropertyType.Int)
  int iInt;

  // implicitly determined types
  @Index()
  String iString;

  @Index()
  int iLong;

  TestEntity.index({
    this.iString,
    this.iLong,
    this.iInt,
    this.iShort,
    this.iChar,
  });
}
