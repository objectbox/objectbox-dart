import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
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

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'OB Example',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: MyHomePage(title: 'OB Example'),
      );
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

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
    _gBox = _box;
    onStepCount();
    startForegroundService(steps: 0, yesterdaySteps: 0);
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
                    decoration: BoxDecoration(
                        border:
                            Border(bottom: BorderSide(color: Colors.black12))),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: 18.0, horizontal: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            notes[index].text,
                            style: TextStyle(
                              fontSize: 15.0,
                            ),
                            // Provide a Key for the integration test
                            key: Key('list_item_$index'),
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
                  stream: _listController.stream,
                  builder: (context, snapshot) => ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      itemCount: snapshot.hasData ? snapshot.data!.length : 0,
                      itemBuilder: _itemBuilder(snapshot.data ?? []))))
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

Future<void> startForegroundService({
  required int steps,
  required int yesterdaySteps,
}) async {
  if (await FlutterForegroundTask.isRunningTask) return;
  await FlutterForegroundTask.init(
    printDevLog: true,
    notificationOptions: NotificationOptions(
      channelId: 'steps',
      channelName: 'Steps',
      channelImportance: NotificationChannelImportance.MAX,
      priority: NotificationPriority.MAX,
      visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      iconData: NotificationIconData(
        name: "stat_name",
        resType: ResourceType.mipmap,
        resPrefix: ResourcePrefix.ic,
      ),
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      autoRunOnBoot: true,
    ),
  );
  await startPeriodicTask(steps: steps, yesterdaySteps: yesterdaySteps);
}

Future<void> startPeriodicTask({
  required int steps,
  required int yesterdaySteps,
}) async {
  await FlutterForegroundTask.start(
    notificationTitle: "Today: $steps steps",
    notificationText: 'Yesterday: $yesterdaySteps steps',
    callback: periodicTaskFun,
  );
}

class StepCount {}

Box<Note>? _gBox;
final _stepCountStream =
    Stream<StepCount?>.periodic(const Duration(seconds: 10)).asBroadcastStream();

void periodicTaskFun() async {
  print('periodicTaskFun() called'); // TODO this is never called...
  StreamSubscription<StepCount?>? streamSubscription;
  // LocalDataSource? localDataSource;
  FlutterForegroundTask.initDispatcher((timeStamp) async {
    if (streamSubscription != null) {
      return;
    }
    streamSubscription = _stepCountStream.listen(
      (steps) async {
        try {
          print('periodicTaskFun() Isolate: ${Isolate.current.hashCode}   box: $_gBox');
          final items = _gBox?.getAll();
          print('periodicTaskFun() sub: ${items?.length}');
          // TODO DB update should happen here (does in the example)
          await FlutterForegroundTask.update(
            notificationTitle: "Last: ${items?.last.date}",
            notificationText: items?.last.comment,
          );
        } catch (e) {
          print(e);
        }
      },
      cancelOnError: true,
    );
  }, onDestroy: (timeStamp) async {
    await streamSubscription?.cancel();
  });
}


void onStepCount() async {
  // return;
  final streamSubscription = _stepCountStream.listen((steps) {
    final items = _gBox?.getAll();
    print('onStepCount() Isolate: ${Isolate.current.hashCode}   box: $_gBox');
    print('onStepCount(): ${items?.length}');
  }, cancelOnError: true);
}
