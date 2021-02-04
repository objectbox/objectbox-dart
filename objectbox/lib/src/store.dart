import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings/bindings.dart';
import 'bindings/helpers.dart';
import 'box.dart';
import 'common.dart';
import 'model.dart';
import 'modelinfo/index.dart';
import 'sync.dart';
import 'transaction.dart';
import 'util.dart';

/// Represents an ObjectBox database and works together with [Box] to allow
/// getting and putting.
class Store {
  /*late final*/ Pointer<OBX_store> _cStore;
  final _boxes = <Type, Box>{};
  final ModelDefinition _defs;
  bool _closed = false;

  /// A list of observers of the Store.close() event.
  final _onClose = <dynamic, void Function()>{};

  /// Creates a BoxStore using the model definition from the generated
  /// whether this store was created from a pointer (won't close in that case)
  bool _weak = false;

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
  Store(this._defs,
      {String /*?*/ directory,
      int /*?*/ maxDBSizeInKB,
      int /*?*/ fileMode,
      int /*?*/ maxReaders}) {
    var model = Model(_defs.model);

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
              ' - this usually indicates a problem with permissions; '
                  "if you're using Flutter you may need to use "
                  'getApplicationDocumentsDirectory() from the path_provider '
                  'package, see example/README.md';
          throw ObjectBoxException(
              dartMsg: e.dartMsg, nativeCode: e.nativeCode, nativeMsg: msg);
        }
      }
      rethrow;
    }
  }

  /// Create a Dart store instance from an already opened native store pointer.
  /// Used for example to create use the same store from multiple isolates, with
  /// the pointer passed over a stream.
  Store.fromPtr(this._defs, this._cStore)
      : _weak = true; // must not close the same native store twice

  /// Closes this store.
  ///
  /// Don't try to call any other ObjectBox methods after the store is closed.
  void close() {
    if (_closed) return;
    _closed = true;

    _boxes.values.forEach(InternalBoxAccess.close);
    _boxes.clear();

    // Call each "onClose()" event listener.
    // Move the list to prevent "Concurrent modification during iteration".
    _onClose.values.toList(growable: false).forEach((listener) => listener());
    _onClose.clear();

    if (!_weak) checkObx(C.store_close(_cStore));
  }

  /// Returns a cached Box instance.
  Box<T> box<T>() {
    if (!_boxes.containsKey(T)) {
      return _boxes[T] = InternalBoxAccess.create<T>(this, _entityDef());
    }
    return _boxes[T] as Box<T>;
  }

  EntityDefinition<T> _entityDef<T>() {
    final binding = _defs.bindings[T];
    if (binding == null) {
      throw ArgumentError('Unknown entity type ' + T.toString());
    }
    return binding /*!*/ as EntityDefinition<T>;
  }

  /// Executes a given function inside a transaction. Returns [fn]'s result.
  /// Aborts a transaction or rethrows if there's an exception.
  ///
  /// A transaction can group several operations into a single unit of work that
  /// either executes completely or not at all.
  /// The advantage of explicit transactions over the bulk put operations is
  /// that you can perform any number of operations and use objects of multiple
  /// boxes. In addition, you get a consistent (transactional) view on your data
  /// while the transaction is in progress.
  R runInTransaction<R>(TxMode mode, R Function() fn) =>
      Transaction.execute(this, mode, fn);

  /// Return an existing SyncClient associated with the store or null if not
  /// available. Use [Sync.client()] to create one first.
  SyncClient /*?*/ syncClient() => syncClientsStorage[this];

  /// The low-level pointer to this store.
  Pointer<OBX_store> get ptr => _cStore;
}

/// Internal only.
// TODO enable annotation once meta:1.3.0 is out
// @internal
class InternalStoreAccess {
  /// Access entity model for the given class (Dart Type).
  static EntityDefinition<T> entityDef<T>(Store store) => store._entityDef();

  /// Access model definitions
  static ModelDefinition defs(Store store) => store._defs;

  /// Adds a listener to the [store.close()] event.
  static void addCloseListener(
          Store store, dynamic key, void Function() listener) =>
      store._onClose[key] = listener;

  /// Removes a [store.close()] event listener.
  static void removeCloseListener(Store store, dynamic key) =>
      store._onClose.remove(key);
}
