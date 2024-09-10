import 'package:intl/intl.dart';
import 'package:objectbox/objectbox.dart';

// ignore_for_file: public_member_api_docs

@Entity()
class Note {
  int id;

  String text;
  String? comment;

  /// Note: Stored in milliseconds without time zone info.
  DateTime date;

  Note(this.text, {this.id = 0, this.comment, DateTime? date})
      : date = date ?? DateTime.now();

  String get dateFormat => DateFormat('dd.MM.yyyy hh:mm:ss').format(date);
}
