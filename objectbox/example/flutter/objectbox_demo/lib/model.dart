import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import 'package:objectbox/objectbox.dart';

import 'objectbox.g.dart';

// ignore_for_file: public_member_api_docs

@Entity()
class Note extends Equatable {
  Note(this.text, {this.id = 0, this.comment, DateTime? date})
      : date = date ?? DateTime.now();

  int id;

  String text;
  String? comment;

  /// Note: Stored in milliseconds without time zone info.
  DateTime date;

  String get dateFormat => DateFormat('dd.MM.yyyy hh:mm:ss').format(date);

  ToMany<Attachment> attachment = ToMany<Attachment>();

  @override
  List<Object?> get props => [id, text, comment, date];
}

@Entity()
class Attachment extends Equatable {
  Attachment(this.content);

  int id = 0;

  final String content;

  @override
  List<Object?> get props => [id, content];
}
