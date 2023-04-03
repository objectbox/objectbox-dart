import 'dart:io';

void main() {
  // Goals:
  // * remove a property
  // * remove a to-one relation
  // * remove a to-many relation
  // * remove an entity

  File('lib/entities.dart').writeAsStringSync('''
import 'package:objectbox/objectbox.dart';

@Entity()
class A {
  int? id;

  A();
}

@Entity()
class A1 {
  int? id;

  A1();
}
  ''');
}
