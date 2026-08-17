import 'package:objectbox/objectbox.dart';

/// Basic entity used by sync tests as a non-synced entity.
@Entity()
class TestEntity {
  @Id(assignable: true)
  int id = 0;

  String? tString;

  TestEntity({this.id = 0, this.tString});
}
