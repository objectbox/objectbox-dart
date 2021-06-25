import 'dart:io';

void main() {
  // Goals:
  // * add a new property
  // * add a new to-one relation
  // * add a new to-many relation
  // * add a new entity

  File('lib/entities.dart').writeAsStringSync('''
import 'package:objectbox/objectbox.dart';

@Entity()
class A {
  int? id;

  String? text1;

  @Property(uid: 1003)
  String? text2;

  @Property(uid: 1004)
  final relOne = ToOne<B>();

  @Property(uid: 1005)
  final relMany = ToMany<B>();

  A();
}

@Entity(uid: 2000)
class B {
  int? id;

  bool? value;

  B();
}
  ''');
}
