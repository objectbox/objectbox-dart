import 'package:objectbox/objectbox.dart';

@Entity()
class Task {
  @Id()
  int id;
  String text;

  bool status;

  Task(this.text, {this.id = 0, this.status = false});

  // Here, the To-One relation on the base application is replaced by To-Many.
  // https://docs.objectbox.io/relations#to-many-relations
  final owner = ToMany<Owner>();

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

  // Relationships can be accessed in the reverse direction via Backlinks()
  @Backlink()
  final tasks = ToMany<Task>();

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
