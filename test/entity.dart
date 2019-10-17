import "package:objectbox/objectbox.dart";
part 'entity.g.dart';

@Entity()
class TestEntity {
  @Id()
  int id;

  String text;

  TestEntity();
  TestEntity.constructWithId(this.id, this.text);
  TestEntity.construct(this.text);
}
