import 'dart:typed_data';

import 'package:objectbox/objectbox.dart';

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
      this.tListString,
      [this.tInt = 0,
      this.tLong = 0,
      this.tFloat = 0,
      int unknown = 42, // breaks up here, the remaining params use cascade
      this.tDouble = 0]);
}

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
      required this.tListString,
      int unknown = 42, // skipped, but continues using the constructor
      required this.tLong});
}
