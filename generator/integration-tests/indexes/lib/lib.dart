import 'package:objectbox/objectbox.dart';

@Entity()
class A {
  int? id;

  @Index()
  int? indexed;

  @Unique()
  String? unique;

  @Unique()
  @Index(type: IndexType.value)
  String? uniqueValue;

  @Unique()
  @Index(type: IndexType.hash)
  String? uniqueHash;

  @Unique()
  @Index(type: IndexType.hash64)
  String? uniqueHash64;

  @Unique()
  int? uid;

  A();
}
