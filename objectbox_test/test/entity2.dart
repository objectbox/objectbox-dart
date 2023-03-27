import 'package:objectbox/objectbox.dart';
import 'package:test/test.dart';

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

/// Test how DB operations behave if property converters throw.
@Entity()
class ThrowingInConverters {
  int id = 0;

  final bool throwOnGet;
  final bool throwOnPut;

  ThrowingInConverters({this.throwOnGet = false, this.throwOnPut = false});

  int get value =>
      throwOnPut ? throw Exception('Getter invoked, e.g. box.put()') : 1;

  set value(int val) {
    if (throwOnGet) throw Exception('Setter invoked, e.g. box.get())');
  }

  static Matcher throwsIn(String op) =>
      throwsA(predicate((Exception e) => e.toString().contains('$op invoked')));
}
