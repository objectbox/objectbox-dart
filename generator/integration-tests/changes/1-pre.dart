import 'dart:io';

void main() {
  File('lib/entities.dart').writeAsStringSync('''
import 'package:objectbox/objectbox.dart';

@Entity()
class A {
  @Id()
  int id;

  String text1;

  A();
}
  ''');
}
