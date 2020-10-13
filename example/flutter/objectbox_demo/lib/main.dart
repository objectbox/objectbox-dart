import 'package:flutter/material.dart';
import 'package:objectbox/objectbox.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'objectbox.g.dart';
import 'package:objectbox/src/observable.dart';
import 'dart:async';
import 'dart:io';

@Entity()
class Note {
  @Id()
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

class ViewModel {
  Store _store;
  Box<Note> _box;
  Query<Note> _query;

  ViewModel(Directory dir) {
    _store = Store(getObjectBoxModel(), directory: dir.path + '/objectbox');
    _box = Box<Note>(_store);

    final dateProp = Note_.date;
    final dummyCondition = dateProp.greaterThan(0);

    _query = _box
        .query(dummyCondition)
        .order(dateProp, flags: Order.descending)
        .build();
  }

  void addNote(Note note) => _box.put(note);

  void removeNote(Note note) => _box.remove(note.id);

  Stream<List<Note>> get queryStream => _query.findStream();

  List<Note> get allNotes => _query.find();

  void dispose() {
    _query.close();
    _store.unsubscribe();
    _store.close();
  }
}

class _MyHomePageState extends State<MyHomePage> {
  final _noteInputController = TextEditingController();
  final _listController = StreamController<List<Note>>(sync:true);
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
    );
  }
}
