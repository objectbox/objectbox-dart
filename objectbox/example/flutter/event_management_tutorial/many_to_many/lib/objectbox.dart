import 'package:flutter/material.dart';
import 'model.dart';
import 'objectbox.g.dart';

/// Provides access to the ObjectBox Store throughout the app.
///
/// Create this in the apps main function.
class ObjectBox {
  late final Store store;

  late final Box<Task> taskBox;
  late final Box<Owner> ownerBox;
  late final Box<Event> eventBox;

  late final Stream<Query<Event>> eventsStream;

  ObjectBox._create(this.store) {
    taskBox = Box<Task>(store);
    ownerBox = Box<Owner>(store);
    eventBox = Box<Event>(store);

    // Prepare a Query for all tasks and events.
    // https://docs.objectbox.io/queries
    final qBuilderEvents = eventBox.query()..order(Event_.date);
    eventsStream = qBuilderEvents.watch(triggerImmediately: true);

    if (eventBox.isEmpty()) {
      _putDemoData();
    }
  }

  /// Create an instance of ObjectBox to use throughout the app.
  static Future<ObjectBox> create() async {
    // Future<Store> openStore() {...} is defined in the generated objectbox.g.dart
    final store = await openStore();
    return ObjectBox._create(store);
  }

  void _putDemoData() {
    Event event = Event("One Direction Concert",
        date: DateTime.now(), location: "Miami, Florida");

    Owner owner1 = Owner('Roger');
    Owner owner2 = Owner('Eren');
    Owner owner3 = Owner('John');

    Task task1 = Task('This is a shared task.');
    task1.owner.addAll([owner1, owner2, owner3]); //set the relation

    Task task2 = Task('This is Eren\'s task.');
    task2.owner.add(owner2);

    event.tasks.addAll([task1, task2]);

    // Task and Owner objects will also be put along with Event.
    // ToOne and ToMany will put new Objects when the source object is put.
    // If the target objects already existed, then only the relation is mapped.
    eventBox.put(event);
  }

  void addTask(String taskText, List<Owner> owners, Event event) {
    Task newTask = Task(taskText);

    newTask.owner.addAll(owners);

    Event updatedEvent = event;
    updatedEvent.tasks.add(newTask);

    int eventId = eventBox.put(updatedEvent);

    debugPrint(
        "Added Task: ${newTask.text} assigned to ${newTask.owner.map((owner) => owner.name).join(", ")} in event: ${eventBox.get(eventId)?.name}");
  }

  void addEvent(String name, DateTime date, String location) {
    Event newEvent = Event(name, date: date, location: location);

    eventBox.put(newEvent);
    debugPrint("Added Event: ${newEvent.name}");
  }

  int addOwner(String newOwner) {
    Owner ownerToAdd = Owner(newOwner);
    int newObjectId = ownerBox.put(ownerToAdd);

    return newObjectId;
  }

  Stream<List<Event>> getEvents() {
    // Query for all events ordered by date.
    // https://docs.objectbox.io/queries
    final builder = eventBox.query()..order(Event_.date);

    return builder.watch(triggerImmediately: true).map((query) => query.find());
  }

  Stream<List<Task>> getTasksOfEvent(int eventId) {
    final builder = taskBox.query()..order(Task_.id, flags: Order.descending);
    builder.link(Task_.event, Event_.id.equals(eventId));
    return builder.watch(triggerImmediately: true).map((query) => query.find());
  }
}
