import 'package:objectbox/objectbox.dart';
import 'objectbox.g.dart';

@Entity()
class A {
  int id = 0;

  final bs = ToMany<B>();
}

@Entity()
class B {
  int id = 0;

  final cs = ToMany<C>();
}

@Entity()
class C {
  int id = 0;
}