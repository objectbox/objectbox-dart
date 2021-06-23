import 'dart:collection';
import 'dart:ffi';

import 'package:meta/meta.dart';

import '../modelinfo/entity_definition.dart';
import '../store.dart';
import '../transaction.dart';
import 'bindings/bindings.dart';
import 'bindings/helpers.dart';

// ignore_for_file: public_member_api_docs

/// Represents a native transaction - it is bound to a current thread so never
/// use with asychcronous code, or more specifically, never `await` before
/// calling [close].
@internal
class Transaction {
  final Store _store;
  final bool _isWrite;
  final Pointer<OBX_txn> _cTxn;
  bool _closed = false;

  // We have two ways of keeping cursors because we usually need just one.
  // The variable is faster then the map initialization & access.
  CursorHelper? _firstCursor;
  HashMap<int, CursorHelper>? _cursors;

  Transaction(this._store, TxMode mode)
      : _isWrite = mode == TxMode.write,
        _cTxn = mode == TxMode.write
            ? C.txn_write(InternalStoreAccess.ptr(_store))
            : C.txn_read(InternalStoreAccess.ptr(_store)) {
    checkObxPtr(_cTxn, 'failed to create transaction');
  }

  @pragma('vm:prefer-inline')
  void _finish(bool successful) {
    if (_isWrite) {
      try {
        _mark(successful);
      } finally {
        close();
      }
    } else {
      close();
    }
  }

  @pragma('vm:prefer-inline')
  void commitAndClose() => _finish(true);

  @pragma('vm:prefer-inline')
  void abortAndClose() => _finish(false);

  @pragma('vm:prefer-inline')
  void _mark(bool successful) =>
      checkObx(C.txn_mark_success(_cTxn, successful));

  @pragma('vm:prefer-inline')
  void markSuccessful() => _mark(true);

  @pragma('vm:prefer-inline')
  void markFailed() => _mark(false);

  @pragma('vm:prefer-inline')
  void close() {
    if (_closed) return;
    _closed = true;
    if (_firstCursor != null) {
      _firstCursor!.close();
      _cursors
        ?..values.forEach((c) => c.close())
        ..clear();
    }
    checkObx(C.txn_close(_cTxn));
  }

  /// Returns a cursor for the given entity. No need to close it manually.
  /// Note: the cursor may have already been used, don't rely on its state!
  CursorHelper<T> cursor<T>(EntityDefinition<T> entity) {
    if (_firstCursor == null) {
      return _firstCursor =
          CursorHelper<T>(_store, _cTxn, entity, isWrite: _isWrite);
    } else if (_firstCursor!.entity == entity) {
      return _firstCursor as CursorHelper<T>;
    }
    _cursors ??= HashMap<int, CursorHelper>();
    final entityId = entity.model.id.id;
    final cursors = _cursors!;
    if (!cursors.containsKey(entityId)) {
      cursors[entityId] =
          CursorHelper<T>(_store, _cTxn, entity, isWrite: _isWrite);
    }
    return cursors[entityId] as CursorHelper<T>;
  }

  /// Executes a given function inside a transaction.
  ///
  /// Returns type of [fn] if [return] is called in [fn].
  @pragma('vm:prefer-inline')
  static R execute<R>(Store store, TxMode mode, R Function() fn) {
    // Whether the function is an `async` function. We can't allow those because
    // the isolate could be transferred to another thread during execution.
    // Checking the return value seems like the only thing we can in Dart v2.12.
    if (fn is Future Function() && _nullSafetyEnabled) {
      // This is a special case when the given function always throws. Triggered
      //  in our test code. No need to even start a DB transaction in that case.
      if (fn is Never Function()) {
        // WARNING: don't be tempted to just `return fn();` - the code may
        // execute DB operations which wouldn't be rolled back after the throw.
        throw UnsupportedError('Given transaction callback always fails.');
      }
      throw UnsupportedError(
          'Executing an "async" function in a transaction is not allowed.');
    }

    final tx = Transaction(store, mode);
    try {
      // In theory, we should only mark successful after the function finishes.
      // In practice, it's safe to assume most functions will be successful and
      // thus marking before the call allows us to return directly, before an
      // intermediary variable.
      if (tx._isWrite) tx.markSuccessful();
      if (_nullSafetyEnabled) {
        return fn();
      } else {
        final result = fn();
        if (result is Future) {
          // Let's make sure users change their code not to do use async.
          throw UnsupportedError(
              'Executing an "async" function in a transaction is not allowed.');
        }
        return result;
      }
    } catch (ex) {
      if (tx._isWrite) tx.markFailed();
      rethrow;
    } finally {
      tx.close();
    }
  }
}

/// True if the package enables null-safety (i.e. depends on SDK 2.12+).
/// Otherwise, it's we can distinguish at runtime whether a function is async.
final _nullSafetyEnabled = _nullReturningFn is! Future Function();
final _nullReturningFn = () => null;
