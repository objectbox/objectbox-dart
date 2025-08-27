import 'package:flutter/material.dart';

import 'main.dart';
import 'model.dart';
import 'tag_elements.dart';

/// Interface to add a new or update an existing task, also to add new tags.
///
/// Supports adding or changing the text and setting the associated tag of
/// a task.
class TaskInput extends StatefulWidget {
  final int? taskId;

  /// If [taskId] is not null, the id of the task to edit.
  /// Otherwise, will create a new task.
  const TaskInput({super.key, this.taskId});

  @override
  State<TaskInput> createState() => _TaskInputState();
}

class _TaskInputState extends State<TaskInput> {
  late String appBarTitle;
  Task? existingTask;
  late Tag currentTag;

  final inputController = TextEditingController();
  List<Tag> tags = objectbox.getAllTags();

  /// Reload the tag list and set the selected tag to the added one.
  Future<void> _updateTags(int newTagId) async {
    var newTag = objectbox.getTag(newTagId);
    var newTags = await objectbox.getAllTagsAsync();
    setState(() {
      currentTag = newTag;
      tags = newTags;
    });
  }

  @override
  void initState() {
    super.initState();
    var taskId = widget.taskId;
    if (taskId != null) {
      appBarTitle = "Edit Task";
      var taskToEdit = objectbox.getTask(taskId);
      existingTask = taskToEdit;
      currentTag = taskToEdit.tag.target!;
      inputController.text = taskToEdit.text;
    } else {
      appBarTitle = "Add Task";
      existingTask = null;
      currentTag = objectbox.getFirstTag();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: TextField(controller: inputController),
            ),
            Row(
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Text("Tags: ", style: TextStyle(fontSize: 15.0)),
                ),
                DropdownButton<int>(
                  value: currentTag.id,
                  items: tags.map(buildMenuItem).toList(),
                  underline: Container(
                    height: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onChanged: (value) => {
                    setState(() {
                      currentTag = objectbox.getTag(value!);
                      debugPrint("tag updated to ${currentTag.name}");
                    }),
                  },
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: TextButton(
                    child: const Text('Save'),
                    onPressed: () {
                      setState(() {
                        objectbox.saveTask(
                          existingTask,
                          inputController.text,
                          currentTag,
                        );
                        // Screen is left afterwards, no need to clear or update UI.
                        Navigator.pop(context);
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: NewTag(updateTags: _updateTags),
    );
  }

  DropdownMenuItem<int> buildMenuItem(Tag item) => DropdownMenuItem(
    value: item.id,
    child: Text(
      item.name,
      style: const TextStyle(fontSize: 15.0, color: Colors.black),
    ),
  );
}
