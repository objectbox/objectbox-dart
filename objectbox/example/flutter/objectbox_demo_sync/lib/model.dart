import 'package:intl/intl.dart';
import 'package:objectbox/objectbox.dart';

// ignore_for_file: public_member_api_docs

@Entity()
@Sync()
class Task {
  int id;

  String text;

  /// Note: DateTime is stored in milliseconds without time zone info.
  @Property(type: PropertyType.date)
  DateTime dateCreated;

  @Property(type: PropertyType.date)
  DateTime dateFinished;

  /// Create task with the given text at the current time.
  Task(this.text, {this.id = 0, DateTime? dateCreated, DateTime? dateFinished})
      : dateCreated = dateCreated ?? DateTime.now(),
        dateFinished = dateFinished ?? DateTime.fromMicrosecondsSinceEpoch(0);

  bool isFinished() {
    return dateFinished.millisecondsSinceEpoch != 0;
  }

  void setIsFinished(bool isFinished) {
    if (isFinished) {
      dateFinished = DateTime.now();
    } else {
      dateFinished = DateTime.fromMicrosecondsSinceEpoch(0);
    }
  }

  String get dateCreatedFormat =>
      DateFormat('dd.MM.yy HH:mm:ss').format(dateCreated);

  String get dateFinishedFormat =>
      DateFormat('dd.MM.yy HH:mm:ss').format(dateFinished);

  /// If the task is new returns 'Created on <date>',
  /// if it is finished 'Finished on <date>'. The date is formatted
  /// for the current locale.
  String getStateText() {
    String text;
    if (isFinished()) {
      text = 'Finished on $dateFinishedFormat';
    } else {
      text = 'Created on $dateCreatedFormat';
    }
    return text;
  }
}
