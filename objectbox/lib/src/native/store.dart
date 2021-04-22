import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../common.dart';
import '../modelinfo/index.dart';
import '../transaction.dart';
import '../util.dart';
import 'bindings/bindings.dart';
import 'bindings/helpers.dart';
import 'box.dart';
import 'model.dart';
import 'sync.dart';

/// Represents an ObjectBox database and works together with [Box] to allow
/// getting and putting.
class Store {
  late final Pointer<OBX_store> _cStore;
  final _boxes = <Type, Box>{};
  final ModelDefinition _defs;
  bool _closed = false;

  late final ByteData _reference;

  /// A list of observers of the Store.close() event.
  final _onClose = <dynamic, void Function()>{};

  /// Creates a BoxStore using the model definition from the generated
  /// whether this store was created from a pointer (won't close in that case)
  final bool _weak;

  /// Default value for string query conditions [caseSensitive] argument.
  final bool _queriesCaseSensitiveDefault;

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
  /// TODO have an Options class?
  Store(this._defs,
      {String? directory,
      int? maxDBSizeInKB,
      int? fileMode,
      int? maxReaders,
      bool queriesCaseSensitiveDefault = true})
      : _weak = false,
        _queriesCaseSensitiveDefault = queriesCaseSensitiveDefault {
    var model = Model(_defs.model);

    var opt = C.opt();
    checkObxPtr(opt, 'failed to create store options');

    try {
      checkObx(C.opt_model(opt, model.ptr));
      if (directory != null && directory.isNotEmpty) {
        var cStr = directory.toNativeUtf8();
        try {
          checkObx(C.opt_directory(opt, cStr.cast()));
        } finally {
          malloc.free(cStr);
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
      // 13 = permissions denied, 30 = read-only filesystem
      if (e.message.contains(OBX_ERROR_STORAGE_GENERAL.toString()) &&
          e.message.contains('Dir does not exist') &&
          (e.message.endsWith(' (13)') || e.message.endsWith(' (30)'))) {
        throw ObjectBoxException(e.message +
            ' - this usually indicates a problem with permissions; '
                "if you're using Flutter you may need to use "
                'getApplicationDocumentsDirectory() from the path_provider '
                'package, see example/README.md');
      }
      rethrow;
    }

    // Always create _reference, so it can be non-nullable.
    // Ensure we only try to access the store created in the same process.
    // Also serves as a simple sanity check/hash.
    _reference = ByteData(2 * _int64Size);
    _reference.setUint64(0 * _int64Size, pid);
    _reference.setUint64(1 * _int64Size, _ptr.address);
  }

  /// Create a Dart store instance from an existing native store reference.
  /// Use this if you want to access the same store from multiple isolates.
  /// This results in two (or more) isolates having access to the same
  /// underlying native store. Concurrent access is ensured using implicit or
  /// explicit transactions.
  /// Note: make sure you don't use store in any of the isolates after the
  /// original store is closed (by calling [close()]).
  ///
  /// To do this, you'd send the [reference] over a [SendPort], receive
  /// it in another isolate and pass it to [attach()].
  ///
  /// Example (see test/isolates_test.dart for an actual working example)
  /// ```dart
  /// // Main isolate:
  ///   final store =  Store(getObjectBoxModel())
  ///
  /// ...
  ///
  /// // use the sendPort of another isolate to send an open store reference.
  ///   sendPort.send(store.reference);
  ///
  /// ...
  ///
  /// // receive the reference in another isolate
  ///   Store store;
  ///   // Listen for messages
  ///   await for (final msg in port) {
  ///     if (store == null) {
  ///       // first message data is existing Store's reference
  ///       store = Store.attach(getObjectBoxModel(), msg);
  ///     }
  ///     ...
  ///   }
  /// ```
  Store.fromReference(this._defs, this._reference,
      {bool queriesCaseSensitiveDefault = true})
      // must not close the same native store twice so [_weak]=true
      : _weak = true,
        _queriesCaseSensitiveDefault = queriesCaseSensitiveDefault {
    // see [reference] for serialization order
    final readPid = _reference.getUint64(0 * _int64Size);
    if (readPid != pid) {
      throw ArgumentError("Reference.processId $readPid doesn't match the "
          'current process PID $pid');
    }

    _cStore = Pointer.fromAddress(_reference.getUint64(1 * _int64Size));
    if (_cStore.address == 0) {
      throw ArgumentError.value(_cStore.address, 'reference.nativePointer',
          'Given native pointer is empty');
    }
  }

  /// Returns a store reference you can use to create a new store instance with
  /// a single underlying native store. See [Store.attach()] for more details.
  ByteData get reference => _reference;

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
  @pragma('vm:prefer-inline')
  Box<T> box<T>() {
    /// TODO evaluate performance, maybe we can do better with a fixed-size list
    /// and using entity IDs as indexes. While that would mean there would be
    /// "empty" spaces, these shouldn't be common and we can have an "empty" box
    /// there (to avoid nullable type) - it wouldn't be accessible anyway.
    /// Alternatively, we can flip this over and let T store the box.
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
    return binding as EntityDefinition<T>;
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
  @pragma('vm:prefer-inline')
  R runInTransaction<R>(TxMode mode, R Function() fn) =>
      Transaction.execute(this, mode, fn);

  /// Return an existing SyncClient associated with the store or null if not
  /// available. Use [Sync.client()] to create one first.
  SyncClient? syncClient() => syncClientsStorage[this];

  /// The low-level pointer to this store.
  @pragma('vm:prefer-inline')
  Pointer<OBX_store> get _ptr {
    if (_closed) throw Exception('Cannot access a closed store pointer');
    return _cStore;
  }
}

/// Internal only.
@internal
class InternalStoreAccess {
  /// Access entity model for the given class (Dart Type).
  @pragma('vm:prefer-inline')
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

  /// The low-level pointer to this store.
  @pragma('vm:prefer-inline')
  static Pointer<OBX_store> ptr(Store store) => store._ptr;

  /// String query case-sensitive default
  @pragma('vm:prefer-inline')
  static bool queryCS(Store store) => store._queriesCaseSensitiveDefault;
}

const _int64Size = 8;
