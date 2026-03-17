import 'package:objectbox/objectbox.dart';

@Entity()
@Sync()
class TestEntitySynced {
  int? id;

  int? value;

  TestEntitySynced({this.id, this.value});
}

/// Entity to test Sync clock and precedence annotations
@Entity()
@Sync()
class TestEntityPrecedence {
  @Id()
  int id = 0;

  @SyncClock()
  int? clock = 0;

  @SyncPrecedence()
  int? precedence;
}
