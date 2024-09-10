import 'package:objectbox/objectbox.dart';

@Entity()
class Task {
  @Id()
  int id;
  String text;

  bool status;

  Task(this.text, {this.id = 0, this.status = false});

  // To-one relation to a Owner Object.
  // https://docs.objectbox.io/relations#to-one-relations
  final owner = ToOne<Owner>();

  final event = ToOne<Event>();

  bool setFinished() {
    status = !status;
    return status;
  }
}

@Entity()
class Owner {
  @Id()
  int id;
  String name;

  Owner(this.name, {this.id = 0});
}

@Entity()
class Event {
  @Id()
  int id;
  String name;

  @Property(type: PropertyType.date)
  DateTime? date;

  String? location;

  Event(this.name, {this.id = 0, this.date, this.location});

  @Backlink('event')
  final tasks = ToMany<Task>();
}
