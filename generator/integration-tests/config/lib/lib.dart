import 'dart:typed_data';

import 'package:objectbox/objectbox.dart';

import 'custom/objectbox.g.dart';

@Entity()
class A {
  int? id;
  String? text;

  A();
}
