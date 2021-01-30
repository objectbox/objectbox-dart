import 'dart:ffi';

import 'bindings/bindings.dart';
import 'bindings/helpers.dart';
import 'modelinfo/entity_definition.dart';
import 'store.dart';

enum TxMode {
  Read,
  Write,
}

// TODO enable annotation once meta:1.3.0 is out
// @internal
class Transaction {
  final Store _store;
  final bool _isWrite;
  final Pointer<OBX_txn> _cTxn;
  bool _closed = false;

  // We have two ways of keeping cursors because we usually need just one.
  // The variable is faster then the map initialization & access.
  /*late final*/
  CursorHelper _firstCursor;

  /*late final*/
  Map<int, CursorHelper> _cursors;

  Pointer<OBX_txn> get ptr => _cTxn;

  Transaction(this._store, TxMode mode)
      : _isWrite = mode == TxMode.Write,
        _cTxn = mode == TxMode.Write
            ? C.txn_write(_store.ptr)
            : C.txn_read(_store.ptr) {
    checkObxPtr(_cTxn, 'failed to create transaction');
  }

  void _finish(bool successful) {
    if (_isWrite) {
      try {
        markSuccessful(successful);
      } finally {
        close();
      }
    } else {
      close();
    }
  }

  void commitAndClose() => _finish(true);

  void abortAndClose() => _finish(false);

  void markSuccessful([bool successful = true]) =>
      checkObx(C.txn_mark_success(_cTxn, successful));

  void close() {
    if (_closed) return;
    _closed = true;
    if (_firstCursor != null) {
      _firstCursor.close();
      if (_cursors != null) {
        _cursors.values.forEach((c) => c.close());
        _cursors.clear();
      }
    }
    checkObx(C.txn_close(_cTxn));
  }

  /// Returns a cursor for the given entity. No need to close it manually.
  /// Note: the cursor may have already been used, don't rely on its state!
  CursorHelper<T> cursor<T>(EntityDefinition<T> entity) {
    if (_firstCursor == null) {
      return _firstCursor = CursorHelper<T>(_store, _cTxn, entity, _isWrite);
    } else if (_firstCursor.entity == entity) {
      return _firstCursor as CursorHelper<T>;
    }
    _cursors ??= <int, CursorHelper>{};
    final entityId = entity.model.id.id;
    if (_cursors.containsKey(entityId)) {
      return _cursors[entityId] as CursorHelper<T>;
    }
    return _cursors[entityId] =
        CursorHelper<T>(_store, _cTxn, entity, _isWrite);
  }

  /// Executes a given function inside a transaction.
  ///
  /// Returns type of [fn] if [return] is called in [fn].
  static R execute<R>(Store store, TxMode mode, R Function() fn) {
    final tx = Transaction(store, mode);
    try {
      // In theory, we should only mark successful after the function finishes.
      // In practice, it's safe to assume most functions will be successful and
      // thus marking before the call allows us to return directly, before an
      // intermediary variable.
      if (tx._isWrite) tx.markSuccessful(true);
      return fn();
    } catch (ex) {
      if (tx._isWrite) tx.markSuccessful(false);
      rethrow;
    } finally {
      tx.close();
    }
  }
}
