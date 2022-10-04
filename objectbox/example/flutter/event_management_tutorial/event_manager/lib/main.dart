import 'dart:async';

import 'package:flutter/material.dart';
import 'components/event_add.dart';
import 'components/event_list_view.dart';
import 'objectbox.dart';

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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ObjectBox Relations Application',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Events"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Column(
          children: const [
            Expanded(child: EventList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddEvent()));
          },
          child: const Text("+", style: TextStyle(fontSize: 29))),
    );
  }
}
