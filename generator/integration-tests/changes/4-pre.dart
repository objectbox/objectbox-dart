import 'dart:io';

void main() {
  // Goals:
  // * remove a property
  // * remove an entity

  File("lib/entities.dart").writeAsStringSync('''
import 'package:objectbox/objectbox.dart';

@Entity()
class A {
  @Id()
  int id;

  A();
}
  ''');
}
