import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'model.dart';
import 'objectbox.g.dart'; // created by `flutter pub run build_runner build`

/// Provides access to the ObjectBox Store throughout the app.
///
/// Create this in the apps main function.
class ObjectBox {
  /// The Store of this app.
  late final Store store;

  // Keeping reference to avoid Admin getting closed.
  // ignore: unused_field
  late final Admin _admin;

  /// Two Boxes: one for Tasks, one for Tags.
  late final Box<Task> taskBox;
  late final Box<Tag> tagBox;

  ObjectBox._create(this.store) {
    // Optional: enable ObjectBox Admin on debug builds.
    // https://docs.objectbox.io/data-browser
    if (Admin.isAvailable()) {
      // Keep a reference until no longer needed or manually closed.
      _admin = Admin(store);
    }

    taskBox = Box<Task>(store);
    tagBox = Box<Tag>(store);

    // Add some demo data if the box is empty.
    if (taskBox.isEmpty()) {
      _putDemoData();
    }
  }

  /// Create an instance of ObjectBox to use throughout the app.
  static Future<ObjectBox> create() async {
    // Note: on desktop systems this returns the users documents directory,
    // so make sure to create a unique sub-directory.
    // On mobile using the default (not supplying any directory) is typically
    // fine, as apps have their own directory structure.
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databaseDirectory =
        p.join(documentsDirectory.path, "obx-demo-relations");

    // Future<Store> openStore() {...} is defined in the generated objectbox.g.dart
    final store = await openStore(directory: databaseDirectory);
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

  Stream<List<Task>> getTasks() {
    // Query for all tasks, sorted by their date.
    // https://docs.objectbox.io/queries
    final qBuilderTasks =
        taskBox.query().order(Task_.dateCreated, flags: Order.descending);
    // Build and watch the query,
    // set triggerImmediately to emit the query immediately on listen.
    return qBuilderTasks
        .watch(triggerImmediately: true)
        // Map it to a list of tasks to be used by a StreamBuilder.
        .map((query) => query.find());
  }

  void saveTask(Task? task, String text, Tag tag) {
    if (text.isEmpty) {
      // Do not allow an empty task text.
      // A real app might want to display an UI hint about that.
      return;
    }
    if (task == null) {
      // Add a new task (task id is 0).
      task = Task(text);
    } else {
      // Update an existing task (task id is > 0).
      task.text = text;
    }
    // Set or update the target of the to-one relation to Tag.
    task.tag.target = tag;
    taskBox.put(task);
    debugPrint('Saved task ${task.text} with tag ${task.tag.target!.name}');
  }

  void removeTask(int taskId) {
    taskBox.remove(taskId);
  }

  int addTag(String name) {
    if (name.isEmpty) {
      // Do not allow an empty tag name.
      // A real app might want to display an UI hint about that.
      return -1;
    }
    // Do not allow adding a tag with an existing name.
    // A real app might want to display an UI hint about that.
    final existingTags = tagBox.getAll();
    for (var existingTag in existingTags) {
      if (existingTag.name == name) {
        return -1;
      }
    }

    final newTagId = tagBox.put(Tag(name));
    debugPrint("Added tag: ${tagBox.get(newTagId)!.name}");

    return newTagId;
  }
}
