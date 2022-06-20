import 'package:flutter/material.dart';

import 'main.dart';
import 'model.dart';

import 'tag_elements.dart';

class TaskInput extends StatefulWidget {
  final int? taskId;

  const TaskInput({Key? key, this.taskId}) : super(key: key);

  @override
  State<TaskInput> createState() => _TaskInputState();
}

class _TaskInputState extends State<TaskInput> {
  late String appBarTitle;
  Task? currentTask;
  Tag? currentTag;

  final inputController = TextEditingController();
  List<Tag> tags = objectbox.tagBox.getAll();

  void saveTask(Task editedTask) {
    currentTask = editedTask;

    if (editedTask.text.isEmpty) return;
    Task task = Task(editedTask.text);
    task.tag.target = currentTag;
    objectbox.taskBox.put(task);
    debugPrint('Saved task ${task.text} with tag ${task.tag.target?.name}');

    // List updated via watched query stream.
    inputController.clear(); //create separate functions for these
    currentTask = null;
  }

  /// Reload the tag list and set the selected tag to the added one.
  void _updateTags(int newTagId) {
    var newTag = objectbox.tagBox.get(newTagId);
    var newTags = objectbox.tagBox.getAll();
    setState(() {
      currentTag = newTag;
      tags = newTags;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.taskId != null) {
      appBarTitle = "Edit Task";
      var taskToEdit = objectbox.taskBox.get(widget.taskId!)!;
      currentTask = taskToEdit;
      currentTag = taskToEdit.tag.target;
      inputController.text = taskToEdit.text;
    } else {
      appBarTitle = "Add Task";
      currentTag = objectbox.tagBox.query().build().findFirst();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text(appBarTitle)),
        body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: <Widget>[
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: TextField(
                    controller: inputController,
                  )),
              Row(
                children: <Widget>[
                  const Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Text("Tags: ",
                          style: TextStyle(
                            fontSize: 15.0,
                          ))),
                  DropdownButton<int>(
                      value: currentTag?.id,
                      items: tags.map(buildMenuItem).toList(),
                      underline: Container(
                        height: 2,
                        color: Colors.blueAccent,
                      ),
                      onChanged: (value) => {
                            setState(
                              () {
                                currentTag = objectbox.tagBox.get(value!);
                                debugPrint(
                                    "tag updated to ${currentTag?.name}");
                              },
                            )
                          }),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: TextButton(
                        child: const Text('Save'),
                        onPressed: () {
                          setState(() {
                            currentTask == null
                                ? currentTask = Task(inputController.text)
                                : currentTask?.text = inputController.text;
                            saveTask(currentTask!);
                            Navigator.pop(context);
                          });
                        }),
                  ),
                ],
              ),
              Expanded(
                child: Container(
                  alignment: Alignment.bottomRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.only(bottom: 50.0),
                        child: NewTag(updateTags: _updateTags),
                      ),
                    ],
                  ),
                ),
              ),
            ])));
  }

  DropdownMenuItem<int> buildMenuItem(Tag item) => DropdownMenuItem(
      value: item.id,
      child: Text(
        item.name,
        style: const TextStyle(fontSize: 15.0, color: Colors.black),
      ));
}
