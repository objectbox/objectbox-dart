import 'package:flutter/material.dart';
import 'package:objectbox/objectbox.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
part "main.g.dart";

@Entity()
class Note {
  @Id()
  int id;

  String text;
  String comment;
  int date; // TODO: use DateTime class

  Note();
  Note.construct(this.text) {
    // only uses seconds instead of milliseconds right now, as all instance variables of type "int"
    // but "id" are casted to a 32 bit integer during Flatbuffers marshalling
    date = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }
}

void main() => runApp(OBDemoApp());

class OBDemoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OB Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: OBDemoHomePage(title: 'OB Example'),
    );
  }
}

class OBDemoHomePage extends StatefulWidget {
  OBDemoHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _OBDemoHomePageState createState() => _OBDemoHomePageState();
}

class _OBDemoHomePageState extends State<OBDemoHomePage> {
  final _noteInputController = TextEditingController();
  Store _store;
  Box _box;
  List<Note> _notes = [];

  void _addNote() {
    if (_noteInputController.text.isEmpty) return;
    Note newNote = Note.construct(_noteInputController.text);
    newNote.id = _box.put(newNote);
    setState(() => _notes.add(newNote));
    _noteInputController.text = "";
  }

  void _removeNote(int index) {
    _box.remove(_notes[index].id);
    setState(() => _notes.removeAt(index));
  }

  @override
  void initState() {
    getApplicationDocumentsDirectory().then((dir) {
      _store = Store([Note_OBXDefs], directory: dir.path + "/objectbox");
      _box = Box<Note>(_store);
      List<Note> notesFromDb = _box.getAll();
      setState(() => _notes = notesFromDb);
      // TODO: don't show UI before this point
    });

    super.initState();
  }

  @override
  void dispose() {
    _noteInputController.dispose();
    super.dispose();
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
                          decoration: InputDecoration(hintText: 'Enter new note'),
                          controller: _noteInputController,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 10.0, right: 10.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            "Click a note to remove it",
                            style: new TextStyle(
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
                      onPressed: this._addNote,
                      child: Text("Add"),
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
              itemBuilder: (BuildContext context, int index) {
                return GestureDetector(
                  onTap: () => this._removeNote(index),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 18.0, horizontal: 10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  _notes[index].text,
                                  style: new TextStyle(
                                    fontSize: 15.0,
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(top: 5.0),
                                  child: Text(
                                    "Added on ${new DateFormat('dd.MM.yyyy hh:mm:ss').format(new DateTime.fromMillisecondsSinceEpoch(_notes[index].date * 1000))}",
                                    style: new TextStyle(
                                      fontSize: 12.0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
