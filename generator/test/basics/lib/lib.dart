import 'package:objectbox/objectbox.dart';
import 'objectbox.g.dart';

@Entity()
class Note {
  @Id()
  int id;
  String text;

  Note();
}
