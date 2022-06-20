import 'dart:async';

import 'package:flutter/material.dart';

import 'objectbox.dart';
import 'task_elements.dart';
import 'tasklist_elements.dart';

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
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Column(
          children: <Widget>[
            const SizedBox(
              height: 10,
            ),
            const SwipeLeftNotification(),
            const TaskList(),
            Container(
                padding: const EdgeInsets.only(bottom: 70.0, right: 15),
                child: Align(
                    alignment: Alignment.bottomRight,
                    child: Column(children: [
                      FloatingActionButton.extended(
                        key: const Key('add'),
                        label: const Text('Add Task'),
                        heroTag: null,
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => const TaskInput()));
                        },
                      ),
                    ]))),
          ],
        ),
      );
}
