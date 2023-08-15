import 'dart:io';

void main() {
  // Goals:
  // * rename a property
  // * rename a to-one relation
  // * rename a to-many relation
  // * rename an entity

  File('lib/entities.dart').writeAsStringSync('''
import 'package:objectbox/objectbox.dart';

@Entity()
class A {
  int? id;

  String? text1;

  @Property(uid: 1003)
  String? renamed;

  @Property(uid: 1004)
  final renamedRelOne = ToOne<Renamed>();

  @Property(uid: 1005)
  final renamedRelMany = ToMany<Renamed>();

  A();
}

@Entity()
class A1 {
  int? id;

  A1();
}

@Entity(uid: 2000)
class Renamed {
  int? id;

  bool? value;

  Renamed();
}
  ''');
}
