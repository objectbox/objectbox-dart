import 'package:objectbox/objectbox.dart';

@Entity()
class A {
  int id = 0;

  String text;
  final bs = ToMany<B>();

  @Backlink('a2')
  final d2s = ToMany<D>();

  A(this.text);
}

@Entity()
class B {
  int id = 0;

  String text;
  final cs = ToMany<C>();

  @Backlink()
  final as = ToMany<A>();

  B(this.text);
}

@Entity()
class C {
  int id = 0;

  String text;
  C(this.text);
}

@Entity()
class D {
  int id = 0;

  String text;

  final a1 = ToOne<A>();

  final a2 = ToOne<A>();

  D(this.text);
}
