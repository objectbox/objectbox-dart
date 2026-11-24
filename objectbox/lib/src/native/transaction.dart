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
/// use with asynchronous code, or more specifically, never `await` before
/// calling [successAndClose] or [abortAndClose].
@internal
class Transaction implements Finalizable {
  final Store _store;
  final Pointer<OBX_txn> _cTxn;
  bool _closed = false;
  final TxMode mode;

  // We have two ways of keeping cursors because we usually need just one.
  // The variable is faster then the map initialization & access.
  CursorHelper? _firstCursor;
  HashMap<int, CursorHelper>? _cursors;

  /// Whether this is the outermost transaction of its native store in this
  /// isolate (the native store considers transactions on the same thread
  /// nested).
  final bool _topLevel;

  /// ID of the native store, see [StoreInternal.nativeId].
  final int _storeId;

  /// Number of open transactions by native store ID in this isolate.
  ///
  /// Only used to determine if a new transaction is top-level ([_topLevel]),
  /// so [_finalizer] is only attached to top-level transactions. The native
  /// store nests transactions per native store and thread, but the C API does
  /// not expose if a transaction is top-level, so this mirrors it:
  /// - static, so per isolate: transactions are synchronous, so all open
  ///   transactions of an isolate are on the same thread,
  /// - keyed by native store ID, as [Store] instances attached to the same
  ///   native store share its nesting.
  ///
  /// Once the C API exposes a function to check if a transaction is top-level,
  /// use that and remove this (and [_storeId] and [StoreInternal.nativeId]).
  static final _openCountByStoreId = HashMap<int, int>();

  /// Closes a read and aborts a write transaction that is still open when its
  /// isolate shuts down: for example an isolate terminated via Isolate.kill()
  /// inside a transaction does not run finally blocks. This may run on an
  /// arbitrary thread, which may not be the thread that started the
  /// transaction. But without this, closing the store would wait for a write
  /// transaction forever.
  ///
  /// Only attached to top-level transactions: at isolate shutdown, native
  /// finalizers run in the order objects were attached (this is undocumented VM
  /// behavior, see the notes in `Store._attachFinalizer()`), so a parent would
  /// be closed before its nested transactions. But closing the parent deletes
  /// the native transaction, which a nested write transaction would then access
  /// when closed (use after free). Closing the parent alone is sufficient, it
  /// aborts the native transaction (the nested ones are then leaked).
  ///
  /// Keeps the finalizer itself reachable (static), otherwise it might be
  /// disposed of before the finalizer callback gets a chance to run.
  static final _finalizer = NativeFinalizer(C.addresses.txn_close.cast());

  /// Ensures [_finalizer] exists. Call before the finalizer of Store is created:
  /// at isolate shutdown, native finalizers run in the order their finalizer
  /// objects were created, and transactions must be closed before the store.
  /// This works because Dart initializes static fields on access.
  static void initFinalizer() => _finalizer;

  factory Transaction(Store store, TxMode mode) {
    final storeId = store.nativeId;
    final openCount = _openCountByStoreId[storeId] ?? 0;
    final tx = Transaction._(store, mode, storeId, topLevel: openCount == 0);
    // Only count once successfully created.
    _openCountByStoreId[storeId] = openCount + 1;
    return tx;
  }

  Transaction._(this._store, this.mode, this._storeId, {required bool topLevel})
    : _topLevel = topLevel,
      _cTxn =
          mode == TxMode.write
              ? C.txn_write(InternalStoreAccess.cStore(_store))
              : C.txn_read(InternalStoreAccess.cStore(_store)) {
    checkObxPtr(_cTxn, 'failed to create transaction');
    if (_topLevel) _finalizer.attach(this, _cTxn.cast(), detach: this);
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
    if (_topLevel) _finalizer.detach(this);
    final openCount = _openCountByStoreId[_storeId]! - 1;
    if (openCount == 0) {
      _openCountByStoreId.remove(_storeId);
    } else {
      _openCountByStoreId[_storeId] = openCount;
    }
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
