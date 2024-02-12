import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'entity.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

// We want to have types explicit - verifying the return types of functions.
// ignore_for_file: omit_local_variable_types
void main() {
  /// Set up a simple echo isolate with request-response communication.
  /// This isn't really a test, just an example of how isolates can communicate.
  test('isolates two-way communication example', () async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(echoIsolate, receivePort.sendPort);

    var sendPortCompleter = Completer<SendPort>();
    late Completer responseCompleter;
    receivePort.listen((dynamic data) {
      if (data is SendPort) {
        sendPortCompleter.complete(data);
      } else {
        print('Main received: $data');
        responseCompleter.complete(data);
      }
    });

    // Receive the SendPort from the Isolate
    SendPort sendPort = await sendPortCompleter.future;

    call(String message) {
      responseCompleter = Completer<String>();
      sendPort.send(message);
      return responseCompleter.future;
    }

    // Send a message to the isolate
    expect(await call('hello'), equals('re:hello'));
    expect(await call('foo'), equals('re:foo'));

    isolate.kill(priority: Isolate.immediate);
    receivePort.close();
  });

  /// Work with a single store across multiple isolates using
  /// the legacy way of passing a pointer reference to the isolate.
  test('single store using reference', () async {
    await testUsingStoreFromIsolate(
        storeCreatorFromRef, (env) => env.store.reference);
  });

  /// Work with a single store across multiple isolates using
  /// the directory path to attach to an existing store.
  test('single store using attach', () async {
    Store.debugLogs = true;
    await testUsingStoreFromIsolate(storeCreatorAttach, (env) => env.dbDirPath);
  });
}

// Note: can't use closures, are only supported from Dart SDK 2.15.
Store storeCreatorFromRef(dynamic msg) =>
    Store.fromReference(getObjectBoxModel(), msg as ByteData);

Store storeCreatorAttach(dynamic msg) {
  Store.debugLogs = true;
  return Store.attach(getObjectBoxModel(), msg as String);
}

class IsolateInitMessage {
  SendPort sendPort;
  Store Function(dynamic) storeCreator;

  IsolateInitMessage(this.sendPort, this.storeCreator);
}

Future<void> testUsingStoreFromIsolate(Store Function(dynamic) storeCreator,
    dynamic Function(TestEnv) storeRefGetter) async {
  final receivePort = ReceivePort();
  final initMessage = IsolateInitMessage(receivePort.sendPort, storeCreator);
  await Isolate.spawn(createDataIsolate, initMessage);

  final sendPortCompleter = Completer<SendPort>();
  late Completer<dynamic> responseCompleter;
  receivePort.listen((dynamic data) {
    if (data is SendPort) {
      sendPortCompleter.complete(data);
    } else {
      print('Main received: $data');
      responseCompleter.complete(data);
    }
  });

  // Receive the SendPort from the Isolate
  SendPort sendPort = await sendPortCompleter.future;

  call(dynamic message) {
    responseCompleter = Completer<dynamic>();
    sendPort.send(message);
    return responseCompleter.future;
  }

  // Pass the store to the isolate
  final env = TestEnv('isolates');
  addTearDown(() => env.closeAndDelete());

  expect(Store.isOpen(env.dbDirPath), true);
  expect(await call(storeRefGetter(env)), equals('store set'));

  {
    // check simple box operations
    expect(env.box.isEmpty(), isTrue);
    expect(await call(['put', 'Foo']), equals(1)); // returns inserted id = 1
    expect(env.box.get(1)!.tString, equals('Foo'));
  }

  {
    // verify that query streams (using observers) work fine across isolates
    final queryStream = env.box.query().watch();
    // starts a subscription
    final futureFirst = queryStream.map((q) => q.find()).first;
    expect(await call(['put', 'Bar']), equals(2));
    List<TestEntity> found = await futureFirst.timeout(defaultTimeout);
    expect(found.length, equals(2));
    expect(found.last.tString, equals('Bar'));
  }

  expect(await call(['close']), equals('done'));

  receivePort.close();
}

// Echoes back any received message.
void echoIsolate(SendPort sendPort) async {
  // Open the ReceivePort to listen for incoming messages
  final port = ReceivePort();

  // Send the port where the main isolate can contact us
  sendPort.send(port.sendPort);

  // Listen for messages
  await for (final data in port) {
    // `data` is the message received.
    print('Isolate received: $data');
    sendPort.send('re:$data');
  }
}

// Creates data in the background, in the [Store] received as the first message.
void createDataIsolate(IsolateInitMessage initMessage) async {
  // Open the ReceivePort to listen for incoming messages
  final port = ReceivePort();

  // Send the port where the main isolate can contact us
  final sendPort = initMessage.sendPort;
  sendPort.send(port.sendPort);

  Store? store;
  // Listen for messages
  await for (final msg in port) {
    if (store == null) {
      // first message data is Store's C pointer address
      store = initMessage.storeCreator(msg);
      sendPort.send('store set');
    } else {
      print('Isolate received: $msg');
      if (msg is! List) {
        sendPort.send('unknown message type, list expected');
      } else {
        final data = msg as List<String>;
        switch (data[0]) {
          case 'put':
            final id = Box<TestEntity>(store).put(TestEntity(tString: data[1]));
            sendPort.send(id);
            break;
          case 'close':
            store.close();
            Isolate.exit(sendPort, 'done');
          default:
            sendPort.send('unknown message: $data');
        }
      }
    }
  }
}
