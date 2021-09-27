import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:objectbox/objectbox.dart';

import 'objectbox.g.dart';

// ignore_for_file: public_member_api_docs

@Entity()
class Note {
  int id;

  String text;
  String? comment;
  DateTime date;

  Note(this.text, {this.id = 0, this.comment, DateTime? date})
      : date = date ?? DateTime.now();

  String get dateFormat => DateFormat('dd.MM.yyyy hh:mm:ss').format(date);
}

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'OB Example',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const MyHomePage(title: 'OB Example'),
      );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class ViewModel {
  final Store _store;
  final Box<Note> _box;
  late final Stream<Query<Note>> _queryStream;

  ViewModel(this._store) : _box = Box<Note>(_store) {
    final qBuilder = _box.query()..order(Note_.date, flags: Order.descending);
    _queryStream = qBuilder.watch(triggerImmediately: true);
  }

  void addNote(Note note) => _box.put(note);

  void removeNote(Note note) => _box.remove(note.id);

  void dispose() {
    _store.close();
  }
}

class _MyHomePageState extends State<MyHomePage> {
  final _noteInputController = TextEditingController();
  final _listController = StreamController<List<Note>>(sync: true);
  late final ViewModel _vm;

  void _addNote() {
    if (_noteInputController.text.isEmpty) return;
    _vm.addNote(Note(_noteInputController.text));
    _noteInputController.text = '';
  }

  @override
  void initState() {
    super.initState();

    openStore().then((Store store) {
      _vm = ViewModel(store);

      setState(() {});

      _listController.addStream(_vm._queryStream.map((q) => q.find()));
    });
  }

  @override
  void dispose() {
    _noteInputController.dispose();
    _listController.close();
    _vm.dispose();
    super.dispose();
  }

  GestureDetector Function(BuildContext, int) _itemBuilder(List<Note> notes) =>
      (BuildContext context, int index) => GestureDetector(
            onTap: () => _vm.removeNote(notes[index]),
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
                          decoration:
                              const InputDecoration(hintText: 'Enter a new note'),
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
                  stream: _listController.stream,
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
