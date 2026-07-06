// Web implementation of the internal Transaction, backed by the web engine's
// undo log. Mirrors the native protocol used by shared relation code:
// construct to begin, then successAndClose()/abortAndClose() exactly once.
// ignore_for_file: public_member_api_docs

import 'package:meta/meta.dart';

import '../transaction.dart' show TxMode;
import 'store.dart';

@internal
class Transaction {
  final Store _store;
  final TxMode mode;
  bool _closed = false;

  Transaction(this._store, this.mode) {
    InternalStoreAccess.engine(_store).beginTx();
  }

  void successAndClose() {
    if (_closed) return;
    _closed = true;
    InternalStoreAccess.engine(_store).commitTx();
  }

  void abortAndClose() {
    if (_closed) return;
    _closed = true;
    InternalStoreAccess.engine(_store).abortTx();
  }
}
