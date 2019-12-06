import 'dart:io';

void main() {
  // Goals:
  // * rename a property
  // * rename an entity

  File("lib/entities.dart").writeAsStringSync('''
import 'package:objectbox/objectbox.dart';

@Entity()
class A {
  @Id()
  int id;
  
  String text1;
  
  @Property(uid: 1003)
  String renamed;

  A();
}

@Entity(uid: 2000)
class Renamed {
  @Id()
  int id;
  
  bool value; 

  Renamed();
}
  ''');
}
