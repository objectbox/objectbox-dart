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
/// calling [successAndClose] or [abortAndClose].
@internal
class Transaction {
  final Store _store;
  final Pointer<OBX_txn> _cTxn;
  bool _closed = false;
  final TxMode mode;

  // We have two ways of keeping cursors because we usually need just one.
  // The variable is faster then the map initialization & access.
  CursorHelper? _firstCursor;
  HashMap<int, CursorHelper>? _cursors;

  Transaction(this._store, this.mode)
      : _cTxn = mode == TxMode.write
            ? C.txn_write(InternalStoreAccess.ptr(_store))
            : C.txn_read(InternalStoreAccess.ptr(_store)) {
    checkObxPtr(_cTxn, 'failed to create transaction');
  }

  /// Indicates the write transaction is complete and closes it.
  /// Read transactions are just closed.
  /// If this is a top-level transaction, commits all changes.
  @pragma('vm:prefer-inline')
  void successAndClose() => _finish(true);

  /// Aborts a write transaction by just closing it.
  /// Read transactions are just closed.
  @pragma('vm:prefer-inline')
  void abortAndClose() => _finish(false);

  @pragma('vm:prefer-inline')
  void _finish(bool successful) {
    if (_closed) return;
    _closed = true;
    final firstCursor = _firstCursor;
    if (firstCursor != null) {
      firstCursor.close();
      final cursors = _cursors;
      if (cursors != null) {
        for (var cursor in cursors.values) {
          cursor.close();
        }
      }
      _cursors?.clear();
    }
    if (mode == TxMode.write && successful) {
      checkObx(C.txn_success(_cTxn));
    } else {
      // Also aborts write transactions, read transactions are just closed.
      checkObx(C.txn_close(_cTxn));
    }
  }

  /// Returns a cursor for the given entity. No need to close it manually.
  /// Note: the cursor may have already been used, don't rely on its state!
  CursorHelper<T> cursor<T>(EntityDefinition<T> entity) {
    if (_firstCursor == null) {
      return _firstCursor = CursorHelper<T>(_store, _cTxn, entity);
    } else if (_firstCursor!.entity == entity) {
      return _firstCursor as CursorHelper<T>;
    }
    _cursors ??= HashMap<int, CursorHelper>();
    final entityId = entity.model.id.id;
    final cursors = _cursors!;
    if (!cursors.containsKey(entityId)) {
      cursors[entityId] = CursorHelper<T>(_store, _cTxn, entity);
    }
    return cursors[entityId] as CursorHelper<T>;
  }
}
