import 'dart:typed_data';

import 'package:objectbox/objectbox.dart';
import 'objectbox.g.dart';

@Entity()
class A {
  int id;
  String text;

  A();
}

@Entity()
class B {
  @Id()
  int identifier;

  B();
}

@Entity()
@Sync()
class D {
  int id;

  D();
}

@Entity()
class T {
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

  // implicitly determined types
  String tString;

  @Property(type: PropertyType.date)
  int tDate;

  @Property(type: PropertyType.dateNano)
  int tDateNano;

  @Property(type: PropertyType.byteVector)
  List<int> tListInt; // truncates int to 8-bits

  Int8List tInt8List;

  Uint8List tUint8List;

  List<String> tListString;
}

@Entity()
class Unsigned {
  int id;

  @Property(type: PropertyType.byte, signed: false)
  int tByte;

  @Property(type: PropertyType.short, signed: false)
  int tShort;

  @Property(type: PropertyType.char, signed: false)
  int tChar;

  @Property(type: PropertyType.int, signed: false)
  int tInt;

  @Property(signed: false)
  int tLong;
}
