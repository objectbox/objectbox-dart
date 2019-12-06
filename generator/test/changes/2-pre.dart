import 'dart:io';

void main() {
  // Goals:
  // * add a new property
  // * add a new entity

  File("lib/entities.dart").writeAsStringSync('''
import 'package:objectbox/objectbox.dart';

@Entity()
class A {
  @Id()
  int id;
  
  String text1;
  
  @Property(uid: 1003)
  String text2;

  A();
}

@Entity(uid: 2000)
class B {
  @Id()
  int id;
  
  bool value; 

  B();
}
  ''');
}
