import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'bindings/bindings.dart';
import 'bindings/helpers.dart';
import 'box.dart';
import 'modelinfo/index.dart';
import 'model.dart';
import 'common.dart';
import 'util.dart';
import 'sync.dart';

enum TxMode {
  Read,
  Write,
}

/// Represents an ObjectBox database and works together with [Box] to allow getting and putting Objects of
/// specific type.
class Store {
  /*late final*/ Pointer<OBX_store> _cStore;
  final ModelDefinition defs;

  /// Creates a BoxStore using the model definition from your
  /// `objectbox.g.dart` file.
  ///
  /// For example in a Flutter app:
  /// ```dart
  /// getApplicationDocumentsDirectory().then((dir) {
  ///   _store = Store(getObjectBoxModel(), directory: dir.path + "/objectbox");
  /// });
  /// ```
  ///
  /// Or for a Dart app:
  /// ```dart
  /// var store = Store(getObjectBoxModel());
  /// ```
  ///
  /// See our examples for more details.
  Store(this.defs,
      {String /*?*/ directory,
      int /*?*/ maxDBSizeInKB,
      int /*?*/ fileMode,
      int /*?*/ maxReaders}) {
    var model = Model(defs.model);

    var opt = C.opt();
    checkObxPtr(opt, 'failed to create store options');

    try {
      checkObx(C.opt_model(opt, model.ptr));
      if (directory != null && directory.isNotEmpty) {
        var cStr = Utf8.toUtf8(directory).cast<Int8>();
        try {
          checkObx(C.opt_directory(opt, cStr));
        } finally {
          free(cStr);
        }
      }
      if (maxDBSizeInKB != null && maxDBSizeInKB > 0) {
        C.opt_max_db_size_in_kb(opt, maxDBSizeInKB);
      }
      if (fileMode != null && fileMode >= 0) {
        C.opt_file_mode(opt, fileMode);
      }
      if (maxReaders != null && maxReaders > 0) {
        C.opt_max_readers(opt, maxReaders);
      }
    } catch (e) {
      C.opt_free(opt);
      rethrow;
    }
    _cStore = C.store_open(opt);

    try {
      checkObxPtr(_cStore, 'failed to create store');
    } on ObjectBoxException catch (e) {
      // Recognize common problems when trying to open/create a database
      // 10199 = OBX_ERROR_STORAGE_GENERAL
      if (e.nativeCode == 10199 &&
          e.nativeMsg != null &&
          e.nativeMsg /*!*/ .contains('Dir does not exist')) {
        // 13 = permissions denied, 30 = read-only filesystem
        if (e.nativeMsg /*!*/ .endsWith(' (13)') ||
            e.nativeMsg /*!*/ .endsWith(' (30)')) {
          final msg = e.nativeMsg /*!*/ +
              " - this usually indicates a problem with permissions; if you're using Flutter you may need to use " +
              'getApplicationDocumentsDirectory() from the path_provider package, see example/README.md';
          throw ObjectBoxException(
              dartMsg: e.dartMsg, nativeCode: e.nativeCode, nativeMsg: msg);
        }
      }
      rethrow;
    }
  }

  /// Closes this store.
  ///
  /// Don't try to call any other ObjectBox methods after the store is closed.
  void close() {
    // Call each "onBeforeClose()" event listener.
    // Move the list to prevent "Concurrent modification during iteration".
    final listeners = StoreCloseObserver.removeAllListeners(this);
    listeners.forEach((listener) => listener());

    checkObx(C.store_close(_cStore));
  }

  /// Returns a cached Box instance.
  Box<T> box<T>() => Box<T>(this);

  EntityDefinition<T> entityDef<T>() {
    final binding = defs.bindings[T];
    if (binding == null) {
      throw ArgumentError('Unknown entity type ' + T.toString());
    }
    return binding /*!*/ as EntityDefinition<T>;
  }

  /// Executes a given function inside a transaction.
  ///
  /// Returns type of [fn] if [return] is called in [fn].
  R runInTransaction<R>(TxMode mode, R Function() fn) {
    return runInTransactionWithPtr(mode, (txn) => fn());
  }

  /// Executes a given function inside a transaction.
  ///
  /// Returns type of [fn] if [return] is called in [fn].
  R runInTransactionWithPtr<R>(
      TxMode mode, R Function(Pointer<OBX_txn> txn) fn) {
    final write = mode == TxMode.Write;
    final txn = write ? C.txn_write(_cStore) : C.txn_read(_cStore);
    checkObxPtr(txn, 'failed to create transaction');
    try {
      if (write) {
        checkObx(C.txn_mark_success(txn, true));
      }
      return fn(txn);
    } catch (ex) {
      if (write) {
        checkObx(C.txn_mark_success(txn, false));
      }
      rethrow;
    } finally {
      checkObx(C.txn_close(txn));
    }
  }

  /// Return an existing SyncClient associated with the store or null if not available.
  /// See [Sync.client()] to create one first.
  SyncClient /*?*/ syncClient() => syncClientsStorage[this];

  /// The low-level pointer to this store.
  Pointer<OBX_store> get ptr => _cStore;
}
