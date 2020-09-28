import 'package:flutter/material.dart';
import 'package:objectbox/objectbox.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'objectbox.g.dart';
import 'package:objectbox/src/observable.dart';
import 'dart:async';

@Entity()
class Note {
  @Id()
  int id;

  String text;
  String comment;
  int date; // TODO: use DateTime class

  Note();

  Note.construct(this.text) {
    date = DateTime.now().millisecondsSinceEpoch;
    print('constructed date: $date');
  }
}

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OB Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage(title: 'OB Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _noteInputController = TextEditingController();
  Store _store;
  Box<Note> _box;
  Query<Note> _query;
  List<Note> _notes = <Note>[];
  StreamSubscription _subscription;

  void _addNote() {
    if (_noteInputController.text.isEmpty) return;
    final newNote = Note.construct(_noteInputController.text);
    newNote.id = _box.put(newNote);
    _noteInputController.text = '';
  }

  void _removeNote(int index) {
    _box.remove(_notes[index].id);
  }

  @override
  void initState() {
    super.initState();

    getApplicationDocumentsDirectory().then((dir) {
      _store = Store(getObjectBoxModel(), directory: dir.path + '/objectbox');
      _box = Box<Note>(_store);
      // TODO: don't show UI before this point
      final dateProp = Note_.date;
      final dummyQuery = dateProp.greaterThan(0);
      _query = _box.query(dummyQuery)
          .order(dateProp, flags: Order.descending).build();
      final stream = _query.findStream();
      _subscription = stream.listen((ns) {
        setState(() => _notes = ns.cast<Note>());
      });

      // default
      setState(() => _notes = _query.find());
    });
  }

  @override
  void dispose() {
    _noteInputController.dispose();
    _query.close();
    _store.unsubscribe();
    _store.close();
    super.dispose();
  }

  GestureDetector _itemBuilder(BuildContext context, int index) {
    return GestureDetector(
      onTap: () => _removeNote(index),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    vertical: 18.0, horizontal: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _notes[index].text,
                      style: TextStyle(
                        fontSize: 15.0,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 5.0),
                      child: Text(
                        "Added on ${DateFormat('dd.MM.yyyy hh:mm:ss')
                            .format(DateTime.fromMillisecondsSinceEpoch(_notes[index].date))}",
                        style: TextStyle(
                          fontSize: 12.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Colors.black12))),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(right: 10.0),
                        child: TextField(
                          decoration:
                              InputDecoration(hintText: 'Enter a new note'),
                          controller: _noteInputController,
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
                ),
                Column(
                  children: <Widget>[
                    RaisedButton(
                      onPressed: _addNote,
                      child: Text('Add'),
                    )
                  ],
                )
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              itemCount: _notes.length,
              itemBuilder: _itemBuilder,
            )
          )
        ]
      ),
    );
  }
}
