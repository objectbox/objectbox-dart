import 'model.dart';
import 'objectbox.g.dart'; // created by `flutter pub run build_runner build`

/// Provides access to the ObjectBox Store throughout the app.
///
/// Create this in the apps main function.
class ObjectBox {
  /// The Store of this app.
  late final Store store;

  /// Two Boxes: one for Tasks, one for Tags.
  late final Box<Task> taskBox;
  late final Box<Tag> tagBox;

  /// A stream of all tasks ordered by date.
  late final Stream<Query<Task>> tasksStream;
  late final Stream<Query<Tag>> tagsStream;

  ObjectBox._create(this.store) {
    taskBox = Box<Task>(store);
    tagBox = Box<Tag>(store);

    // Prepare a Query for all tasks, sorted by their date.
    // The Query is not run until find() is called or it is subscribed to.
    // https://docs.objectbox.io/queries
    final qBuilderTasks = taskBox.query()
      ..order(Task_.dateCreated, flags: Order.descending);
    tasksStream = qBuilderTasks.watch(triggerImmediately: true);

    final qBuilderTags = tagBox.query()..order(Tag_.name);
    tagsStream = qBuilderTags.watch(triggerImmediately: true);

    // Add some demo data if the box is empty.
    if (taskBox.isEmpty()) {
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
    Tag tag1 = Tag('work');
    Tag tag2 = Tag('study');

    Task task1 = Task('This is a work task.');
    task1.tag.target = tag1; //set the relation

    Task task2 = Task('This is a study task.');
    task2.tag.target = tag2;

    // When the Task is put, its Tag will automatically be put into the Tag Box.
    // Both ToOne and ToMany automatically put new Objects when the Object owning them is put.
    taskBox.putMany([task1, task2]);
  }
}
