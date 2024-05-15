import 'dart:typed_data';

import 'package:objectbox/objectbox.dart';

/// A dummy annotation to verify the code is generated properly even with
/// annotations unknown to ObjectBox generator.
class TestingUnknownAnnotation {
  const TestingUnknownAnnotation();
}

/// An unused entity to test there are no name conflicts with ObjectBox classes
/// in generated code. Matches `Condition` in query.dart.
@Entity()
class Condition {
  @Id()
  int id = 0;
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

  // OBXPropertyType.Char | 16-bit unsigned integer
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
      this.ignore,
      this.tDate,
      this.tDateNano});

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

  @Unique(onConflict: ConflictStrategy.replace)
  int? replaceLong;

  TestEntity.uniqueReplace({this.replaceLong, this.tString});

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

@Entity()
class TestEntityScalarVectors {
  @Id()
  int id = 0;

  // 8-bit integer
  @Property(type: PropertyType.byteVector)
  List<int>? tByteList;
  Int8List? tInt8List;
  Uint8List? tUint8List;
  @Property(type: PropertyType.charVector)
  List<int>? tCharList;

  // 16-bit integer
  @Property(type: PropertyType.shortVector)
  List<int>? tShortList;
  Int16List? tInt16List;
  Uint16List? tUint16List;

  // 32-bit integer
  @Property(type: PropertyType.intVector)
  List<int>? tIntList;
  Int32List? tInt32List;
  Uint32List? tUint32List;

  // 64-bit integer
  List<int>? tLongList;
  Int64List? tInt64List;
  Uint64List? tUint64List;

  // 32-bit floating point
  @Property(type: PropertyType.floatVector)
  List<double>? tFloatList;
  Float32List? tFloat32List;

  // 64-bit floating point
  List<double>? tDoubleList;
  Float64List? tFloat64List;

  TestEntityScalarVectors(
      {this.tByteList,
      this.tInt8List,
      this.tUint8List,
      this.tCharList,
      this.tShortList,
      this.tInt16List,
      this.tUint16List,
      this.tIntList,
      this.tInt32List,
      this.tUint32List,
      this.tLongList,
      this.tInt64List,
      this.tUint64List,
      this.tFloatList,
      this.tFloat32List,
      this.tDoubleList,
      this.tFloat64List});

  TestEntityScalarVectors.withData(int nr) {
    final byte = 10 + nr;
    tByteList = [-byte, byte];
    tInt8List = Int8List.fromList(tByteList!);
    tUint8List = Uint8List.fromList([byte, byte + 1]);

    // Pick next largest multiple of 10 that does not longer fit smaller integer.
    final short = 1000 + nr;
    tCharList = [short, short + 1];

    tShortList = [-short, short];
    tInt16List = Int16List.fromList(tShortList!);
    tUint16List = Uint16List.fromList([short, short + 1]);

    final int = 100 * 1000 + nr;
    tIntList = [-int, int];
    tInt32List = Int32List.fromList(tIntList!);
    tUint32List = Uint32List.fromList([int, int + 1]);

    final long = 10 * 1000 * 1000000 + nr;
    tLongList = [-long, long];
    tInt64List = Int64List.fromList(tLongList!);
    tUint64List = Uint64List.fromList([long, long + 1]);

    final float = 20 + nr / 10;
    tFloatList = [-float, float];
    tFloat32List = Float32List.fromList(tFloatList!);
    // 2000.00001 can not longer be represented with 32-bit floating point.
    final double = 2000 + nr / (100000);
    tDoubleList = [-double, double];
    tFloat64List = Float64List.fromList(tDoubleList!);
  }

  /// Creates test data like:
  /// ```
  /// tByteList = [-10,10]..[-19,19]
  /// tCharList = [-10,10]..[-19,19]
  /// tShortList = [-1000,1000]..[-1009,1009]
  /// tIntList = [-100000,100000]..[-100009,100009]
  /// tLongList = [-10000000000,10000000000]..[-10000000009,10000000009]
  /// tFloatList = [-20.0,20.0]..[-20.9,20.9]
  /// tDoubleList = [-2000.0,2000.0]..[-2000.00009,2000.00009]
  /// ```
  static List<TestEntityScalarVectors> createTen() {
    return List.generate(
        10, (index) => TestEntityScalarVectors.withData(index));
  }
}

Function? readDuringReadCalledFromSetter;

@Entity()
class TestEntityReadDuringRead {
  @Id()
  int id = 0;

  List<String> get strings1 => ["A1", "B1"];

  set strings1(List<String> values) {
    if (readDuringReadCalledFromSetter != null) {
      readDuringReadCalledFromSetter!();
    }
  }

  List<String>? strings2;
}

@Entity()
class HnswObject {
  @Id()
  int id = 0;

  String? name;

  @Property(type: PropertyType.floatVector)
  @HnswIndex(dimensions: 2)
  List<double>? floatVector;

  final rel = ToOne<RelatedNamedEntity>();
}

@Entity()
class RelatedNamedEntity {
  @Id()
  int id = 0;

  String? name;
}
