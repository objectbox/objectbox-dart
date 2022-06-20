import 'package:intl/intl.dart';
import 'package:objectbox/objectbox.dart';

import 'objectbox.g.dart';

@Entity() // Signals ObjectBox to create a Box for this class.
class Tag {
  // Every @Entity requires an int property named 'id'
  // or an int property with any name annotated with @Id().
  @Id()
  int id;
  String name;

  Tag(this.name, {this.id = 0});
}

@Entity()
class Task {
  @Id()
  int id;
  String text;

  @Property(type: PropertyType.date)
  DateTime dateCreated;

  @Property(type: PropertyType.date)
  DateTime? dateFinished;

  Task(this.text, {this.id = 0, DateTime? dateCreated})
      : dateCreated = dateCreated ?? DateTime.now();

  String get dateCreatedFormat =>
      DateFormat('dd.MM.yy HH:mm:ss').format(dateCreated);

  String get dateFinishedFormat =>
      DateFormat('dd.MM.yy HH:mm:ss').format(dateFinished!);

  // To-one relation to a Tag Object.
  // https://docs.objectbox.io/relations#to-one-relations
  final tag = ToOne<Tag>();

  /// Returns true if the task has a [dateFinished] value.
  bool isFinished() {
    return dateFinished != null;
  }

  void toggleFinished() {
    if (isFinished()) {
      dateFinished = null;
    } else {
      dateFinished = DateTime.now();
    }
  }

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
