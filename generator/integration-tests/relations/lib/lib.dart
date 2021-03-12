import 'package:objectbox/objectbox.dart';
import 'objectbox.g.dart';

@Entity()
class A {
  int id = 0;

  String text;
  final bs = ToMany<B>();
  A(this.text);
}

@Entity()
class B {
  int id = 0;

  String text;
  final cs = ToMany<C>();
  B(this.text);
}

@Entity()
class C {
  int id = 0;

  String text;
  C(this.text);
}