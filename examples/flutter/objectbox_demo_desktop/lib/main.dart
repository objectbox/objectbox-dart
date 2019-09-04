import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import "package:objectbox/objectbox.dart";

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

    void _testGetById() {
        setState(() {
            _status += "getById\n";
        });
    }

    void _testPut() {
        setState(() {
            _status += "put\n";
        });
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
                                onPressed: _testGetById,
                                child: Text("getById"),
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
