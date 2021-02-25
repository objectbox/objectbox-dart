import 'dart:typed_data';

import 'package:objectbox/objectbox.dart';

/// A dummy annotation to verify the code is generated properly even with
/// annotations unknown to ObjectBox generator.
class TestingUnknownAnnotation {
  const TestingUnknownAnnotation();
}

@Entity()
@TestingUnknownAnnotation()
@Sync()
class TestEntity {
  @TestingUnknownAnnotation()
  int /*?*/ id;

  // implicitly determined types
  String /*?*/ tString;
  int /*?*/ tLong;
  double /*?*/ tDouble;
  bool /*?*/ tBool;
  DateTime /*?*/ tDate;

  @Transient()
  int /*?*/ ignore;

  @Transient()
  int /*?*/ omit, disregard;

  // explicitly declared types

  @Property(type: PropertyType.dateNano)
  DateTime /*?*/ tDateNano;

  // OBXPropertyType.Byte | 1 byte
  @Property(type: PropertyType.byte)
  int /*?*/ tByte;

  // OBXPropertyType.Short | 2 bytes
  @Property(type: PropertyType.short)
  int /*?*/ tShort;

  // OBXPropertyType.Char | 1 byte
  @Property(type: PropertyType.char)
  int /*?*/ tChar;

  // OBXPropertyType.Int |  ob: 4 bytes, dart: 8 bytes
  @Property(type: PropertyType.int)
  int /*?*/ tInt;

  // OBXPropertyType.Float | 4 bytes
  @Property(type: PropertyType.float)
  double /*?*/ tFloat;

  // OBXPropertyType.StringVector
  List<String> /*?*/ tStrings;

  // OBXPropertyType.ByteVector
  @Property(type: PropertyType.byteVector)
  List<int> /*?*/ tByteList;

  // OBXPropertyType.ByteVector
  Int8List /*?*/ tInt8List;

  // OBXPropertyType.ByteVector
  Uint8List /*?*/ tUint8List;

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
      this.tStrings,
      this.tByteList,
      this.tInt8List,
      this.tUint8List,
      this.ignore});

  TestEntity.ignoredExcept(this.tInt) {
    omit = -1;
    disregard = 1;
  }

  @Property(type: PropertyType.byte)
  @Unique()
  int uByte;

  @Property(type: PropertyType.short)
  @Unique()
  int uShort;

  @Property(type: PropertyType.char)
  @Unique()
  int uChar;

  @Property(type: PropertyType.int)
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

  @Property(type: PropertyType.byte)
  @Index()
  int iByte;

  @Property(type: PropertyType.short)
  @Index()
  int iShort;

  @Property(type: PropertyType.char)
  @Index()
  int iChar;

  @Property(type: PropertyType.int)
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

  final relA = ToOne<RelatedEntityA>();
  final relB = ToOne<RelatedEntityB>();

  final relManyA = ToMany<RelatedEntityA>();
}

@Entity()
@Sync()
class RelatedEntityA {
  int id;

  int tInt;
  bool tBool;
  final relB = ToOne<RelatedEntityB>();

  @Backlink('relManyA')
  final testEntities = ToMany<TestEntity>();

  RelatedEntityA({this.id, this.tInt, this.tBool});
}

@Entity()
@Sync()
class RelatedEntityB {
  int id;

  String tString;
  double tDouble;
  final relA = ToOne<RelatedEntityA>();
  final relB = ToOne<RelatedEntityB>();

  @Backlink()
  final testEntities = ToMany<TestEntity>();

  RelatedEntityB({this.id, this.tString, this.tDouble});
}
