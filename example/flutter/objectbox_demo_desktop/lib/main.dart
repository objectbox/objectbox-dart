import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:objectbox/objectbox.dart';
import 'objectbox.g.dart';

@Entity()
class Note {
  @Id()
  int id;

  String text;

  Note();
  Note.construct(this.text);
  toString() => "Note{id: $id, text: $text}";
}

void main() {
  // See https://github.com/flutter/flutter/wiki/Desktop-shells#target-platform-override
  debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "ObjectBox Demo",
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: "Roboto"),
      home: MyHomePage(title: "ObjectBox Demo"),
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
  String _status = "";
  Store _store;
  Box _box;
  int _lastPutId;

  void _testGet() {
    final Note fetchedNote = _lastPutId == null ? null : _box.get(_lastPutId);
    setState(() {
      if (_lastPutId == null) {
        _status += "cannot get, as nothing was put in this session yet\n";
        return;
      }
      _status += "fetched note: $fetchedNote\n";
    });
  }

  void _testPut() {
    _lastPutId = _box.put(Note.construct("Hello"));
    setState(() {
      _status += "put new note with id $_lastPutId\n";
    });
  }

  @override
  void initState() {
    _store = Store(getObjectBoxModel());
    _box = Box<Note>(_store);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              FlatButton(
                onPressed: _testGet,
                child: Text("get"),
                color: Colors.blue,
                textColor: Colors.white,
              ),
              FlatButton(
                onPressed: _testPut,
                child: Text("put"),
                color: Colors.blue,
                textColor: Colors.white,
              ),
            ],
          ),
          Text("$_status"),
        ],
      ),
    );
  }
}
