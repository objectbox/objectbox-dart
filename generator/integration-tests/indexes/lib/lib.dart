import 'package:objectbox/objectbox.dart';
import 'objectbox.g.dart';

@Entity()
class A {
  @Id()
  int id;

  @Index()
  int indexed;

  @Unique()
  String unique;

  @Unique()
  @Index(type: IndexType.value)
  String uniqueValue;

  @Unique()
  @Index(type: IndexType.hash)
  String uniqueHash;

  @Unique()
  @Index(type: IndexType.hash64)
  String uniqueHash64;

  @Unique()
  int uid;

  A();
}
