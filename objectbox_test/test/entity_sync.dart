import 'package:objectbox/objectbox.dart';

@Entity()
@Sync()
class TestEntitySynced {
  int? id;

  int? value;

  TestEntitySynced({this.id, this.value});
}
