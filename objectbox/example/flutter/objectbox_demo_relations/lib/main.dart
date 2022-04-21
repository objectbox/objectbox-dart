import 'dart:async';

import 'package:flutter/material.dart';

import 'model.dart';
import 'objectbox.dart';
import 'objectbox.g.dart';

/// Provides access to the ObjectBox Store throughout the app.
late ObjectBox objectbox;

Future<void> main() async {
  // This is required so ObjectBox can get the application directory
  // to store the database in.
  WidgetsFlutterBinding.ensureInitialized();

  objectbox = await ObjectBox.create();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Task-list app example',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const MyHomePage(title: 'ObjectBox Example'),
      );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _taskInputController = TextEditingController();
  final _tagInputController = TextEditingController();
  final _taskListController = StreamController<List<Task>>(sync: true);
  final _tagListController = StreamController<List<Tag>>(sync: true);

  Tag? _currentTag = objectbox.tagBox.query().build().findFirst();
  Task? _currentTask;

  void _addTask(Tag tagToAdd) {
    if (_taskInputController.text.isEmpty) return;
    Task task = Task(_taskInputController.text);
    task.tag.target = tagToAdd;
    // Putting (or getting) a single object is typically fast enough to do
    // synchronously. To put many objects or do multiple operations consider
    // using store.runInTransactionAsync.
    objectbox.taskBox.put(task);
    _taskInputController.text = '';
    debugPrint('Added Task ${task.text} with tag ${task.tag.target!.name}');
  }

  void _updateTask(Task task, Tag tag) {
    task.text = _taskInputController.text;
    task.tag.target = _currentTag;
    objectbox.taskBox.put(task);
    debugPrint('task ${task.text} has changed');
  }

  void _addTag() {
    if (_tagInputController.text.isEmpty) return;
    objectbox.tagBox.put(Tag(_tagInputController.text));
    _tagInputController.text = '';
  }

  @override
  void initState() {
    super.initState();
    setState(() {});

    _taskListController.addStream(objectbox.tasksStream.map((q) => q.find()));
    _tagListController.addStream(objectbox.tagsStream.map((q) => q.find()));
  }

  @override
  void dispose() {
    _taskInputController.dispose();
    _tagInputController.dispose();
    _taskListController.close();
    _tagListController.close();
    super.dispose();
  }

  Dismissible Function(BuildContext, int) _itemBuilder(List<Task> tasks) =>
      (BuildContext context, int index) => Dismissible(
            background: Container(
              color: Colors.red,
            ),
            key: UniqueKey(), //Key('dismissed_$index'),
            onDismissed: (direction) {
              // Remove the task from the store.
              objectbox.taskBox.remove(tasks[index].id);
              // List updated via watched query stream.
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Task ${tasks[index].id} deleted')));
            },
            child: Row(
              children: <Widget>[
                Checkbox(
                    value: tasks[index].isFinished(),
                    onChanged: (bool? value) {
                      final task = tasks[index];
                      task.toggleFinished();
                      objectbox.taskBox.put(task);
                      // List updated via watched query stream.
                    }),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: Colors.black12))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 18.0, horizontal: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${tasks[index].text} (tag: ${tasks[index].tag.target!.name})',
                            style: tasks[index].isFinished()
                                ? const TextStyle(
                                    color: Colors.grey,
                                    decoration: TextDecoration.lineThrough)
                                : const TextStyle(fontSize: 15.0),
                            // Provide a Key for the integration test
                            key: Key('list_item_$index'),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 5.0),
                            child: Text(
                              tasks[index].getStateText(),
                              style: const TextStyle(
                                fontSize: 12.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                TextButton(
                    child: const Text('Edit'),
                    onPressed: () {
                      _currentTask = objectbox.taskBox.get(tasks[index].id);
                      _taskInputController.text = _currentTask!.text;
                    }),
              ],
            ),
          );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: TextField(
                            decoration: const InputDecoration(
                                hintText: 'Enter a new task'),
                            controller: _taskInputController,
                            onSubmitted: (value) => _addTask(_currentTag!),
                            // Provide a Key for the integration test
                            key: const Key('input'),
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            const Padding(
                              padding: EdgeInsets.only(left: 10.0),
                              child: Text(
                                'Tags:',
                                style: TextStyle(
                                  fontSize: 15.0,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 10.0),
                              child: StatefulBuilder(
                                builder: (BuildContext context,
                                    StateSetter setState) {
                                  return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        StreamBuilder<List<Tag>>(
                                            stream: _tagListController.stream,
                                            builder: (context, snapshot) {
                                              return DropdownButton<String>(
                                                value: _currentTag?.name,
                                                icon: const Icon(
                                                    Icons.arrow_downward),
                                                //elevation: 15,
                                                style: const TextStyle(
                                                    fontSize: 15.0,
                                                    color: Colors.black),
                                                underline: Container(
                                                  height: 2,
                                                  color: Colors.blueAccent,
                                                ),
                                                onChanged: (value) {
                                                  _currentTag = objectbox.tagBox
                                                      .query(Tag_.name
                                                          .equals(value!))
                                                      .build()
                                                      .findFirst();
                                                  setState(() {});
                                                },
                                                items: snapshot.data?.map<
                                                    DropdownMenuItem<
                                                        String>>((Tag value) {
                                                  return DropdownMenuItem<
                                                      String>(
                                                    value: value.name,
                                                    child: Text(value.name),
                                                  );
                                                }).toList(),
                                              );
                                            }),
                                      ]);
                                },
                              ),
                            ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.only(right: 10.0),
                              child: TextButton(
                                  child: const Text('Save'),
                                  onPressed: () {
                                    if (_currentTask != null) {
                                      _updateTask(_currentTask!, _currentTag!);
                                    } else {
                                      _addTask(_currentTag!);
                                    }
                                    // List updated via watched query stream.
                                    _taskInputController.clear();
                                    _currentTask = null;
                                  }),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 20.0, bottom: 10.0),
              child: Align(
                alignment: Alignment.topRight,
                child: Text(
                  'Delete a task by swiping it.',
                  style: TextStyle(
                    fontSize: 11.0,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            Expanded(
                child: StreamBuilder<List<Task>>(
                    stream: _taskListController.stream,
                    builder: (context, snapshot) => ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        itemCount: snapshot.hasData ? snapshot.data!.length : 0,
                        itemBuilder: _itemBuilder(snapshot.data ?? [])))),
          ],
        ),
        // We need a separate submit button because flutter_driver integration
        // test doesn't support submitting a TextField using "enter" key.
        // See https://github.com/flutter/flutter/issues/9383
        floatingActionButton: FloatingActionButton.extended(
          key: const Key('submit'),
          //onPressed: () => _addTask(currentTag),
          label: const Text('New Tag'),
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: const Text('New tag'),
                content: TextField(
                  autofocus: true,
                  decoration:
                      const InputDecoration(hintText: 'Enter the tag name'),
                  controller: _tagInputController,
                ),
                actions: [
                  TextButton(
                    child: const Text('Submit'),
                    onPressed: () {
                      _addTag();
                      // Dropdown updated via watched query stream.
                      Navigator.of(context).pop(_tagInputController.text);
                      _tagInputController.clear();
                    },
                  ),
                ],
              ),
            );
          },
        ),
      );
}
