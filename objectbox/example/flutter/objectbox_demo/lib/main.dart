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
        title: 'OB Example',
        theme: ThemeData(primarySwatch: Colors.teal),
        home: const MyHomePage(title: 'OB Example'),
      );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _noteInputController = TextEditingController();

  Future<void> _addNote() async {
    if (_noteInputController.text.isEmpty) return;
    await objectbox.addNote(_noteInputController.text);
    _noteInputController.text = '';
  }

  @override
  void dispose() {
    _noteInputController.dispose();
    super.dispose();
  }

  GestureDetector Function(BuildContext, int) _itemBuilder(List<Note> notes) =>
      (BuildContext context, int index) => GestureDetector(
            onTap: () => objectbox.removeNote(notes[index].id),
            child: Row(
              children: <Widget>[
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
                            notes[index].text,
                            style: const TextStyle(
                              fontSize: 15.0,
                            ),
                            // Provide a Key for the integration test
                            key: Key('list_item_$index'),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 5.0),
                            child: Text(
                              'Added on ${notes[index].dateFormat}',
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
                          decoration: const InputDecoration(
                              hintText: 'Enter a new note'),
                          controller: _noteInputController,
                          onSubmitted: (value) => _addNote(),
                          // Provide a Key for the integration test
                          key: const Key('input'),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 10.0, right: 10.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Tap a note to remove it',
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
              child: StreamBuilder<List<Note>>(
                  stream: objectbox.getNotes(),
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
          onPressed: _addNote,
          child: const Icon(Icons.add),
        ),
      );
}
