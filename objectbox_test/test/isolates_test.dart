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

  test('killed isolate leaves no open transaction behind', () async {
    final env = TestEnv('isolate-kill-tx');
    addTearDown(() => env.closeAndDelete());
    final started = ReceivePort();
    final worker = await Isolate.spawn(
        writeUntilKilled, [env.dbDirPath, started.sendPort]);
    await started.first;
    started.close();

    // Terminate the worker inside its write transaction; this does not run
    // finally blocks, so the transaction is only closed by its finalizer.
    worker.kill(priority: Isolate.immediate);
    // Give the worker time to shut down (and run its finalizers).
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Closing the store waits for active write transactions: without the
    // finalizer this would wait forever (note: not caught by test timeouts).
    env.store.close();

    // The transaction was aborted, none of its data was committed.
    final store = Store(getObjectBoxModel(), directory: env.dbDirPath);
    addTearDown(() => store.close());
    expect(Box<TestEntity>(store).count(), 0);
  });

  test('isolate exits with active observers', () async {
    final env = TestEnv('isolate-observers');
    addTearDown(() => env.closeAndDelete());
    final exited = ReceivePort();
    await Isolate.spawn(watchAndExit, env.dbDirPath, onExit: exited.sendPort);
    await exited.first;
    exited.close();

    // The observers of the exited isolate were closed by their finalizers;
    // changes must not fail (e.g. notify a dead isolate) and closing works.
    env.box.put(TestEntity(tString: 'after exit'));
    expect(env.box.count(), 1);
  });

  /// Work with a single store across multiple isolates using
  /// the legacy way of passing a pointer reference to the isolate.
  test('single store using reference', () async {
    await testUsingStoreFromIsolate(
        storeCreatorFromRef,
        // ignore: deprecated_member_use
        (env) => env.store.reference);
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
// ignore: deprecated_member_use
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

/// Subscribes to changes and exits without canceling the subscriptions.
void watchAndExit(String dbDirPath) {
  final store = Store.attach(getObjectBoxModel(), dbDirPath);
  store.watch<TestEntity>().listen((_) {});
  store.entityChanges.listen((_) {});
  Box<TestEntity>(store).query().watch().listen((_) {});
  Isolate.exit();
}

/// Puts objects in a write transaction until killed.
void writeUntilKilled(List<Object> args) {
  final store = Store.attach(getObjectBoxModel(), args[0] as String);
  final box = Box<TestEntity>(store);
  try {
    store.runInTransaction(TxMode.write, () {
      // Signal transaction has started
      (args[1] as SendPort).send(null);
      // Keep running for a while to allow this to get killed: can't use sleep
      // as it will prevent the isolate from getting killed, so keep updating
      // the same object to avoid consuming too much disk space.
      final testObject = TestEntity();
      for (var i = 0; i < 100000000; i++) {
        box.put(testObject..tInt = i);
      }
    });
  } finally {
    print('never reached: finally close store');
    store.close();
  }
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
