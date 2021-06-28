import 'dart:typed_data';

import 'package:objectbox/objectbox.dart';

/// A dummy annotation to verify the code is generated properly even with
/// annotations unknown to ObjectBox generator.
class TestingUnknownAnnotation {
  const TestingUnknownAnnotation();
}

@Entity()
@TestingUnknownAnnotation()
class TestEntity {
  @TestingUnknownAnnotation()
  @Id(assignable: true)
  int id = 0;

  // implicitly determined types
  String? tString;
  int? tLong;
  double? tDouble;
  bool? tBool;
  DateTime? tDate;

  @Transient()
  int? ignore;

  @Transient()
  int? omit, disregard;

  // explicitly declared types

  @Property(type: PropertyType.dateNano)
  DateTime? tDateNano;

  // OBXPropertyType.Byte | 1 byte
  @Property(type: PropertyType.byte)
  int? tByte;

  // OBXPropertyType.Short | 2 bytes
  @Property(type: PropertyType.short)
  int? tShort;

  // OBXPropertyType.Char | 1 byte
  @Property(type: PropertyType.char)
  int? tChar;

  // OBXPropertyType.Int |  ob: 4 bytes, dart: 8 bytes
  @Property(type: PropertyType.int, signed: false)
  int? tInt;

  // OBXPropertyType.Float | 4 bytes
  @Property(type: PropertyType.float)
  double? tFloat;

  // OBXPropertyType.StringVector
  List<String>? tStrings;

  // OBXPropertyType.ByteVector
  @Property(type: PropertyType.byteVector)
  List<int>? tByteList;

  // OBXPropertyType.ByteVector
  Int8List? tInt8List;

  // OBXPropertyType.ByteVector
  Uint8List? tUint8List;

  TestEntity(
      {this.tString,
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

  TestEntity.filled({
    this.id = 1,
    this.tString = 'Foo',
    this.tBool = true,
    this.tByte = 42,
    this.tChar = 24,
    this.tShort = 1234,
    this.tInt = 123456789,
    this.tLong = 123456789123456789,
    this.tFloat = 4.5,
    this.tDouble = 2.3,
  }) {
    tStrings = ['foo', 'bar'];
    tByteList = [1, 2, 3];
    tInt8List = Int8List.fromList([-4, 5, 6]);
    tUint8List = Uint8List.fromList([7, 8, 9]);
  }

  TestEntity.ignoredExcept(this.tInt) : tString = '' {
    omit = -1;
    disregard = 1;
  }

  @Property(type: PropertyType.byte)
  @Unique()
  int? uByte;

  @Property(type: PropertyType.short)
  @Unique()
  int? uShort;

  @Property(type: PropertyType.char)
  @Unique()
  int? uChar;

  @Property(type: PropertyType.int)
  @Unique()
  int? uInt;

  // implicitly determined types
  @Unique()
  String? uString;

  @Unique()
  int? uLong;

  TestEntity.unique({
    this.uString,
    this.uLong,
    this.uInt,
    this.uShort,
    this.uByte,
    this.uChar,
  }) : tString = '';

  @Property(type: PropertyType.byte)
  @Index()
  int? iByte;

  @Property(type: PropertyType.short)
  @Index()
  int? iShort;

  @Property(type: PropertyType.char)
  @Index()
  int? iChar;

  @Property(type: PropertyType.int)
  @Index()
  int? iInt;

  // implicitly determined types
  @Index()
  String? iString;

  @Index()
  int? iLong;

  TestEntity.index({
    this.iString,
    this.iLong,
    this.iInt,
    this.iShort,
    this.iByte,
    this.iChar,
  }) : tString = '';

  final relA = ToOne<RelatedEntityA>();
  final relB = ToOne<RelatedEntityB>();

  final relManyA = ToMany<RelatedEntityA>();
}

@Entity()
class RelatedEntityA {
  int? id;

  int? tInt;
  bool? tBool;
  final relB = ToOne<RelatedEntityB>();

  @Backlink('relManyA')
  final testEntities = ToMany<TestEntity>();

  RelatedEntityA({this.id, this.tInt, this.tBool});
}

@Entity()
class RelatedEntityB {
  int? id;

  String? tString;
  double? tDouble;
  final relA = ToOne<RelatedEntityA>();
  final relB = ToOne<RelatedEntityB>();

  @Backlink()
  final testEntities = ToMany<TestEntity>();

  RelatedEntityB({this.id, this.tString, this.tDouble});
}

@Entity()
class TestEntityNonRel {
  int? id;

  String? tString;
  int? tLong;
  double? tDouble;
  bool? tBool;
  DateTime? tDate;

  @Property(type: PropertyType.dateNano)
  DateTime? tDateNano;

  @Property(type: PropertyType.byte)
  int? tByte;

  @Property(type: PropertyType.short)
  int? tShort;

  @Property(type: PropertyType.char)
  int? tChar;

  @Property(type: PropertyType.int)
  int? tInt;

  @Property(type: PropertyType.float)
  double? tFloat;

  // OBXPropertyType.StringVector
  List<String>? tStrings;

  // OBXPropertyType.ByteVector
  @Property(type: PropertyType.byteVector)
  List<int>? tByteList;

  // OBXPropertyType.ByteVector
  Int8List? tInt8List;

  // OBXPropertyType.ByteVector
  Uint8List? tUint8List;

  TestEntityNonRel();

  TestEntityNonRel.filled({
    this.id = 1,
    this.tString = 'Foo',
    this.tBool = true,
    this.tByte = 42,
    this.tChar = 24,
    this.tShort = 1234,
    this.tInt = 123456789,
    this.tLong = 123456789123456789,
    this.tFloat = 4.5,
    this.tDouble = 2.3,
  }) {
    tStrings = ['foo', 'bar'];
    tByteList = [1, 2, 3];
    tInt8List = Int8List.fromList([-4, 5, 6]);
    tUint8List = Uint8List.fromList([7, 8, 9]);
  }
}

// non-nullable fields
@Entity()
class TestEntityNotNull {
  @Id(assignable: true)
  int id;

  // implicitly determined types
  String tString;
  int tLong;
  double tDouble;
  bool tBool;
  DateTime tDate;

  @Property(type: PropertyType.dateNano)
  DateTime tDateNano;

  List<String> tStrings;

  // OBXPropertyType.ByteVector
  @Property(type: PropertyType.byteVector)
  List<int> tByteList;

  // OBXPropertyType.ByteVector
  Int8List tInt8List;

  // OBXPropertyType.ByteVector
  Uint8List tUint8List;

  TestEntityNotNull(
      {this.id = 0,
      this.tString = 'Foo',
      this.tBool = true,
      this.tLong = 123456789123456789,
      this.tDouble = 2.3,
      DateTime? tDate,
      DateTime? tDateNano,
      List<String>? tStrings,
      List<int>? tByteList,
      Int8List? tInt8List,
      Uint8List? tUint8List})
      : tDate = tDate ?? DateTime.now(),
        tDateNano = tDateNano ?? DateTime.now(),
        tStrings = tStrings ?? [],
        tByteList = tByteList ?? [],
        tInt8List = tInt8List ?? Int8List(0),
        tUint8List = tUint8List ?? Uint8List(0);
}
