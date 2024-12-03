import 'dart:async';

import 'package:flutter/material.dart';

import 'model.dart';
import 'objectbox.dart';

// ignore_for_file: public_member_api_docs

/// Provides access to the ObjectBox Store throughout the app.
late ObjectBox objectbox;

Future<void> main() async {
  // This is required so ObjectBox can get the application directory
  // to store the database in.
  WidgetsFlutterBinding.ensureInitialized();

  objectbox = await ObjectBox.create();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'OB Example (sync)',
        theme: ThemeData(primarySwatch: Colors.teal),
        home: const MyHomePage(title: 'OB Example (sync)'),
      );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _textInputController = TextEditingController();

  Future<void> _addTask() async {
    if (_textInputController.text.isEmpty) return;
    await objectbox.addTask(_textInputController.text);
    _textInputController.text = '';
  }

  @override
  void dispose() {
    _textInputController.dispose();
    super.dispose();
  }

  Widget Function(BuildContext, int) _itemBuilder(List<Task> tasks) =>
      (BuildContext context, int index) => Dismissible(
            background: Container(color: Colors.red),
            key: UniqueKey(),
            onDismissed: (direction) {
              objectbox.removeTask(tasks[index].id);
              // List updated via watched query stream.
            },
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    // draw bottom border
                    decoration: const BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: Colors.black12))),
                    padding: const EdgeInsets.symmetric(
                        vertical: 18.0, horizontal: 10.0),
                    child: Row(
                      children: [
                        Checkbox(
                            value: tasks[index].isFinished(),
                            onChanged: (bool? value) {
                              // not tri-state, so value is never null
                              objectbox.changeTaskFinished(
                                  tasks[index], value!);
                              // List updated via watched query stream.
                            }),
                        Container(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                tasks[index].text,
                                // strike-through text style for finished tasks
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Column(children: <Widget>[
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
                          decoration:
                              const InputDecoration(hintText: 'Enter new task'),
                          controller: _textInputController,
                          onSubmitted: (value) => _addTask(),
                          // Provide a Key for the integration test
                          key: const Key('input'),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 10.0, right: 10.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Delete a task by swiping it',
                            style: TextStyle(
                              fontSize: 11.0,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          Expanded(
              child: StreamBuilder<List<Task>>(
                  stream: objectbox.getTasks(),
                  builder: (context, snapshot) => ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      itemCount: snapshot.hasData ? snapshot.data!.length : 0,
                      itemBuilder: _itemBuilder(snapshot.data ?? []))))
        ]),
        // We need a separate submit button because flutter_driver integration
        // test doesn't support submitting a TextField using "enter" key.
        // See https://github.com/flutter/flutter/issues/9383
        floatingActionButton: FloatingActionButton(
          key: const Key('submit'),
          onPressed: _addTask,
          child: const Icon(Icons.add),
        ),
      );
}
