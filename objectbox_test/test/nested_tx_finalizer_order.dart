// Not a test suite, a program started by a test in isolates_test.dart:
// dart test/nested_tx_finalizer_order.dart <database directory>
//
// An isolate exits inside a nested write transaction, so the transactions are
// only closed by finalizers when the isolate shuts down. The (temporary) debug
// finalizer of Transaction logs which transactions get finalized to stderr,
// like "obx-txn-finalizer top-level: ...". Exits with code 0 if the
// transactions were aborted and the store could be closed.

import 'dart:io';
import 'dart:isolate';

import 'entity.dart';
import 'objectbox.g.dart';

void _exitInNestedWriteTx(List<Object> args) {
  final store = Store.attach(getObjectBoxModel(), args[0] as String);
  final box = Box<TestEntityNonRel>(store);
  store.runInTransaction(TxMode.write, () {
    box.put(TestEntityNonRel());
    store.runInTransaction(TxMode.write, () {
      box.put(TestEntityNonRel());
      // Exits immediately, does not run finally blocks: both transactions stay
      // open and are closed by their finalizers.
      // Conditional, as runInTransaction rejects callbacks returning Never.
      if (args.isNotEmpty) Isolate.exit();
    });
  });
}

Future<void> main(List<String> args) async {
  final store = Store(getObjectBoxModel(), directory: args[0]);
  final exited = ReceivePort();
  final errors = ReceivePort();
  await Isolate.spawn(
    _exitInNestedWriteTx,
    <Object>[args[0]],
    onExit: exited.sendPort,
    onError: errors.sendPort,
  );
  errors.listen((error) {
    stderr.writeln('Isolate failed: $error');
    exit(1);
  });
  await exited.first;
  // Give the isolate time to shut down (and run its finalizers).
  await Future<void>.delayed(const Duration(milliseconds: 500));
  // Waits for active write transactions, so would hang if they were not closed.
  store.close();
  // The transactions were aborted, none of their data was committed.
  final reopened = Store(getObjectBoxModel(), directory: args[0]);
  final count = Box<TestEntityNonRel>(reopened).count();
  reopened.close();
  if (count != 0) {
    stderr.writeln('Expected no objects, but found $count');
    exit(1);
  }
  exit(0);
}
