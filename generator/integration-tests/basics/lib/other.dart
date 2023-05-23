import 'dart:typed_data';

import 'package:objectbox/objectbox.dart';

/// Entity with non-null properties and constructor with positional parameters.
@Entity()
class NonNullA {
  int id;

  // implicit PropertyType.bool
  bool tBool;

  @Property(type: PropertyType.byte)
  int tByte;

  @Property(type: PropertyType.short)
  int tShort;

  @Property(type: PropertyType.char)
  int tChar;

  @Property(type: PropertyType.int)
  int tInt;

  // implicit PropertyType.long
  int tLong;

  @Property(type: PropertyType.float)
  double tFloat;

  // implicit PropertyType.double
  double tDouble;

  // note the default value - missing in constructor, uses cascade
  String tString = '';

  @Property(type: PropertyType.date)
  int tDate;

  @Property(type: PropertyType.dateNano)
  int tDateNano;

  @Property(type: PropertyType.byteVector)
  List<int> tListInt; // truncates int to 8-bits

  Int8List tInt8List;

  Uint8List tUint8List;

  @Property(type: PropertyType.charVector)
  List<int> tCharList;

  @Property(type: PropertyType.shortVector)
  List<int> tShortList;
  Int16List tInt16List;
  Uint16List tUint16List;

  @Property(type: PropertyType.intVector)
  List<int> tIntList;
  Int32List tInt32List;
  Uint32List tUint32List;

  List<int> tLongList;
  Int64List tInt64List;
  Uint64List tUint64List;

  @Property(type: PropertyType.floatVector)
  List<double> tFloatList;
  Float32List tFloat32List;

  List<double> tDoubleList;
  Float64List tFloat64List;

  List<String> tListString;

  NonNullA(
      this.id,
      this.tBool,
      this.tByte,
      this.tShort,
      this.tChar,
      this.tDate,
      this.tDateNano,
      this.tListInt,
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
      this.tFloat64List,
      this.tListString,
      [this.tInt = 0,
      this.tLong = 0,
      this.tFloat = 0,
      int unknown = 42, // breaks up here, the remaining params use cascade
      this.tDouble = 0]);
}

/// Entity with non-null properties and constructor with named optional parameters.
@Entity()
class NonNullB {
  int id;

  // implicit PropertyType.bool
  bool tBool;

  @Property(type: PropertyType.byte)
  int tByte;

  @Property(type: PropertyType.short)
  int tShort;

  @Property(type: PropertyType.char)
  int tChar;

  @Property(type: PropertyType.int)
  int tInt;

  // implicit PropertyType.long
  int tLong;

  @Property(type: PropertyType.float)
  double tFloat;

  // implicit PropertyType.double
  double tDouble;

  String tString = '';

  @Property(type: PropertyType.date)
  int tDate;

  @Property(type: PropertyType.dateNano)
  int tDateNano;

  @Property(type: PropertyType.byteVector)
  List<int> tListInt; // truncates int to 8-bits

  Int8List tInt8List;

  Uint8List tUint8List;

  @Property(type: PropertyType.charVector)
  List<int> tCharList;

  @Property(type: PropertyType.shortVector)
  List<int> tShortList;
  Int16List tInt16List;
  Uint16List tUint16List;

  @Property(type: PropertyType.intVector)
  List<int> tIntList;
  Int32List tInt32List;
  Uint32List tUint32List;

  List<int> tLongList;
  Int64List tInt64List;
  Uint64List tUint64List;

  @Property(type: PropertyType.floatVector)
  List<double> tFloatList;
  Float32List tFloat32List;

  List<double> tDoubleList;
  Float64List tFloat64List;

  List<String> tListString;

  NonNullB(this.id,
      {required this.tBool,
      required this.tByte,
      required this.tShort,
      required this.tChar,
      required this.tInt,
      required this.tFloat,
      required this.tDouble,
      required this.tString,
      required this.tDate,
      required this.tDateNano,
      required this.tListInt,
      required this.tInt8List,
      required this.tUint8List,
      required this.tCharList,
      required this.tShortList,
      required this.tInt16List,
      required this.tUint16List,
      required this.tIntList,
      required this.tInt32List,
      required this.tUint32List,
      required this.tLongList,
      required this.tInt64List,
      required this.tUint64List,
      required this.tFloatList,
      required this.tFloat32List,
      required this.tDoubleList,
      required this.tFloat64List,
      required this.tListString,
      int unknown = 42, // skipped, but continues using the constructor
      required this.tLong});
}
