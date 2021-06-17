import 'package:objectbox/objectbox.dart';

// Testing a model for entities in multiple files is generated properly
@Entity()
class TestEntity2 {
  @Id(assignable: true)
  int? id;

  @Unique()
  int? value;

  TestEntity2({this.id});
}

@Entity()
@Sync()
class TestEntitySynced {
  int? id;

  int? value;

  TestEntitySynced({this.id, this.value});
}

@Entity()
class TreeNode {
  int id = 0;

  final String path; // just to help debugging, not used anywhere

  final parent = ToOne<TreeNode>();

  @Backlink()
  final children = ToMany<TreeNode>();

  TreeNode(this.path);
}
