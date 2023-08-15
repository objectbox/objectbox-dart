import 'dart:io';

void main() {
  // Goals:
  // * add a new entity lexicographically in between the existing ones to check
  //   that IDs are not re-assigned.

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

@Entity()
class A1 {
  int? id;

  A1();
}

@Entity(uid: 2000)
class B {
  int? id;

  bool? value;

  B();
}
  ''');
}
