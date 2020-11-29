import 'package:objectbox/objectbox.dart';
import 'package:objectbox/src/bindings/bindings.dart';

/// A dummy annotation to verify the code is generated properly even with annotations unknown to ObjectBox generator.
class TestingUnknownAnnotation {
  const TestingUnknownAnnotation();
}

@Entity()
@TestingUnknownAnnotation()
@Sync()
class TestEntity {
  @Id()
  @TestingUnknownAnnotation()
  int /*?*/ id;

  // implicitly determined types
  String /*?*/ tString;
  int /*?*/ tLong;
  double /*?*/ tDouble;
  bool /*?*/ tBool;

  @Transient()
  int /*?*/ ignore;

  @Transient()
  int /*?*/ omit, disregard;

  // explicitly declared types, see OB-C, objectbox.h

  // OBXPropertyType.Byte | 1 byte
  @Property(type: OBXPropertyType.Byte)
  int /*?*/ tByte;

  // OBXPropertyType.Short | 2 bytes
  @Property(type: OBXPropertyType.Short)
  int /*?*/ tShort;

  // OBXPropertyType.Char | 1 byte
  @Property(type: OBXPropertyType.Char)
  int /*?*/ tChar;

  // OBXPropertyType.Int |  ob: 4 bytes, dart: 8 bytes
  @Property(type: OBXPropertyType.Int)
  int /*?*/ tInt;

  // OBXPropertyType.Float | 4 bytes
  @Property(type: OBXPropertyType.Float)
  double /*?*/ tFloat;

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

  @Property(type: OBXPropertyType.Byte)
  @Unique()
  int uByte;

  @Property(type: OBXPropertyType.Short)
  @Unique()
  int uShort;

  @Property(type: OBXPropertyType.Char)
  @Unique()
  int uChar;

  @Property(type: OBXPropertyType.Int)
  @Unique()
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
    this.uByte,
    this.uChar,
  });

  @Property(type: OBXPropertyType.Byte)
  @Index()
  int iByte;

  @Property(type: OBXPropertyType.Short)
  @Index()
  int iShort;

  @Property(type: OBXPropertyType.Char)
  @Index()
  int iChar;

  @Property(type: OBXPropertyType.Int)
  @Index()
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
    this.iByte,
    this.iChar,
  });
}
