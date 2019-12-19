import 'package:objectbox/objectbox.dart';
import 'objectbox.g.dart';
export 'other.dart';

@Entity()
class A {
  @Id()
  int id;
  String text;

  A();
}

@Entity()
class B {
  @Id() // TODO support id without an annotation
  int id;

  B();
}
