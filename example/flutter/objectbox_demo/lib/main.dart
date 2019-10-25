import 'package:flutter/material.dart';
import "package:objectbox/objectbox.dart";
import 'package:flutter/services.dart' show rootBundle;
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
    date = new DateTime.now().millisecondsSinceEpoch;
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
    Note newNote = Note.construct(_noteInputController.text);
    _box.put(newNote);
    setState(() => _notes.add(newNote));
    _noteInputController.text = "";
  }

  @override
  void initState() {
    _store = Store([Note_OBXDefs]);
    _box = Box<Note>(_store);
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
      body: Padding(
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
    );
  }
}
