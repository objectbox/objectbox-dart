import 'dart:async';

import 'package:flutter/material.dart';
import 'package:objectbox_flutter_libs/objectbox_flutter_libs.dart';

import 'objectbox.dart';
import 'task_elements.dart';
import 'tasklist_elements.dart';

/// Provides access to the ObjectBox Store throughout the app.
late ObjectBox objectbox;

Future<void> main() async {
  // This is required so ObjectBox can get the application directory
  // to store the database in.
  WidgetsFlutterBinding.ensureInitialized();

  loadObjectBoxLibraryAndroidCompat();
  objectbox = await ObjectBox.create();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Task-list app example',
    theme: ThemeData(primarySwatch: Colors.teal),
    home: const MyHomePage(title: 'ObjectBox Example'),
  );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    // Note: testing with Flutter 3.7 which still requires const for children.
    // ignore: prefer_const_constructors
    body: Column(
      children: const [
        SizedBox(height: 10),
        SwipeLeftNotification(),
        TaskList(),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      key: const Key('add'),
      label: const Text('Add Task'),
      icon: const Icon(Icons.add),
      heroTag: null,
      onPressed: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => const TaskInput()));
      },
    ),
  );
}
