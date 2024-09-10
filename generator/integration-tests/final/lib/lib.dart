import 'dart:typed_data';

import 'package:objectbox/objectbox.dart';

// Test all final fields; Id must be self-assigned.
@Entity()
class A {
  @Id(assignable: true)
  final int id;
  final bool tBool;
  final int tLong;
  final double tDouble;
  final String tString;
  @Property(type: PropertyType.date)
  final int tDate;
  @Property(type: PropertyType.dateNano)
  final int tDateNano;
  @Property(type: PropertyType.byteVector)
  final List<int> tListInt; // truncates int to 8-bits
  final Int8List tInt8List;
  final Uint8List tUint8List;
  final List<String> tListString;

  A(
      this.id,
      this.tLong,
      this.tDouble,
      this.tString,
      this.tDate,
      this.tDateNano,
      this.tListInt,
      this.tUint8List,
      this.tListString,
      bool tBool,
      Int8List tInt8List)
      : tBool = tBool,
        tInt8List = tInt8List;
}

// Test getters and setters with a private field. Let's make the getter and the
// setter non-trivial, just in case it had any influence.
// Since a combination of a getter and a setter is recognized like a standard
// field, it is stored in the database, even recognized as an ID automatically.
@Entity()
class B {
  String _id = '0'; // String, just because we can...

  int get id => int.parse(_id);

  set id(int value) =>
      _id = (value == 0) ? throw 'why are you setting zero?' : value.toString();

  // Note: let's test a "common" getter-only field - it's not stored because
  // there's no setter.
  @override
  int get hashCode => id;
}

// Test getter-only non-final ID (must be self-assigned).
// Note: currently fails to generate code with the following error:
//     entity C: ID property not found - either define an integer field named
//     ID/id/... (case insensitive) or add @Id annotation to any integer field
// @Entity()
// class C {
//   int _id = 111;
//
//   int get id => _id;
// }
