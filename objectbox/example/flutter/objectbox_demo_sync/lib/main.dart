import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:objectbox/objectbox.dart';

import 'objectbox.g.dart';

@Entity()
@Sync()
class Note {
  int id;

  String text;
  String comment;
  int date;

  Note();

  Note.construct(this.text) {
    date = DateTime.now().millisecondsSinceEpoch;
    print('constructed date: $date');
  }

  String get dateFormat => DateFormat('dd.MM.yyyy hh:mm:ss')
      .format(DateTime.fromMillisecondsSinceEpoch(date));
}

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OB Example (sync)',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage(title: 'OB Example (sync)'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class ViewModel {
  Store _store;
  Box<Note> _box;
  Query<Note> _query;

  ViewModel(Directory dir) {
    _store = Store(getObjectBoxModel(), directory: dir.path + '/objectbox');
    _box = Box<Note>(_store);

    final dateProp = Note_.date;

    _query = _box.query().order(dateProp, flags: Order.descending).build();

    // TODO configure actual sync server address and authentication
    // For configuration and docs, see objectbox/lib/src/sync.dart
    // 10.0.2.2 is your host PC if an app is run in an Android emulator.
    // 127.0.0.1 is your host PC if an app is run in an iOS simulator.
    final syncServerIp = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
    final syncClient =
        Sync.client(_store, 'ws://$syncServerIp:9999', SyncCredentials.none());
    syncClient.start();
  }

  void addNote(Note note) => _box.put(note);

  void removeNote(Note note) => _box.remove(note.id);

  Stream<List<Note>> get queryStream => _query.findStream();

  List<Note> get allNotes => _query.find();

  void dispose() {
    _query.close();
    _store.close();
  }
}

class _MyHomePageState extends State<MyHomePage> {
  final _noteInputController = TextEditingController();
  final _listController = StreamController<List<Note>>(sync: true);
  Stream<List<Note>> _stream;
  ViewModel _vm;

  void _addNote() {
    if (_noteInputController.text.isEmpty) return;
    _vm.addNote(Note.construct(_noteInputController.text));
    _noteInputController.text = '';
  }

  @override
  void initState() {
    super.initState();

    getApplicationDocumentsDirectory().then((dir) {
      _vm = ViewModel(dir);
      _stream = _listController.stream;

      setState(() {});

      _listController.add(_vm.allNotes);
      _listController.addStream(_vm.queryStream);
    });
  }

  @override
  void dispose() {
    _noteInputController.dispose();
    _listController.close();
    _vm.dispose();
    super.dispose();
  }

  GestureDetector Function(BuildContext, int) _itemBuilder(List<Note> notes) {
    return (BuildContext context, int index) {
      return GestureDetector(
        onTap: () => _vm.removeNote(notes[index]),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Container(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(vertical: 18.0, horizontal: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        notes[index].text,
                        style: TextStyle(
                          fontSize: 15.0,
                        ),
                        // Provide a Key for the integration test
                        key: Key('list_item_${index}'),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 5.0),
                        child: Text(
                          'Added on ${notes[index].dateFormat}',
                          style: TextStyle(
                            fontSize: 12.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black12))),
              ),
            ),
          ],
        ),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(children: <Widget>[
        Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.0),
                      child: TextField(
                        decoration:
                            InputDecoration(hintText: 'Enter a new note'),
                        controller: _noteInputController,
                        onSubmitted: (value) => _addNote(),
                        // Provide a Key for the integration test
                        key: Key('input'),
                      ),
                    ),
                    Padding(
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
                stream: _stream,
                builder: (context, snapshot) {
                  return ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      itemCount: snapshot.hasData ? snapshot.data.length : 0,
                      itemBuilder: _itemBuilder(snapshot.data));
                }))
      ]),
      // We need a separate submit button because flutter_driver integration
      // test doesn't support submitting a TextField using "enter" key.
      // See https://github.com/flutter/flutter/issues/9383
      floatingActionButton: FloatingActionButton(
        key: Key('submit'),
        onPressed: _addNote,
        child: Icon(Icons.add),
      ),
    );
  }
}
