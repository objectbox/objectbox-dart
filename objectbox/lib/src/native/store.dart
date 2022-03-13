library store;

import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';
import 'package:objectbox/src/native/version.dart';
import 'package:path/path.dart' as path;

import '../common.dart';
import '../modelinfo/index.dart';
import '../transaction.dart';
import '../util.dart';
import 'bindings/bindings.dart';
import 'bindings/flatbuffers.dart';
import 'bindings/helpers.dart';
import 'box.dart';
import 'model.dart';
import 'sync.dart';

part 'observable.dart';

/// Represents an ObjectBox database and works together with [Box] to allow
/// getting and putting.
class Store {
  /// Path of the default directory, currently 'objectbox'.
  static const String defaultDirectoryPath = 'objectbox';

  /// Enables a couple of debug logs.
  /// This meant for tests only; do not enable for releases!
  static bool debugLogs = false;

  late Pointer<OBX_store> _cStore;
  late final Pointer<OBX_dart_finalizer> _cFinalizer;
  HashMap<int, Type>? _entityTypeById;
  final _boxes = HashMap<Type, Box>();
  final ModelDefinition _defs;
  Stream<List<Type>>? _entityChanges;
  final _reader = ReaderWithCBuffer();
  Transaction? _tx;

  /// Path to the database directory.
  final String directoryPath;

  /// Absolute path to the database directory, used for open check.
  final String _absoluteDirectoryPath;

  late final ByteData _reference;

  /// A list of observers of the Store.close() event.
  final _onClose = <dynamic, void Function()>{};

  /// Creates a BoxStore using the model definition from the generated
  /// whether this store was created from a pointer (won't close in that case)
  final bool _weak;

  /// Default value for string query conditions [caseSensitive] argument.
  final bool _queriesCaseSensitiveDefault;

  static String _safeDirectoryPath(String? path) =>
      (path == null || path.isEmpty) ? defaultDirectoryPath : path;

  /// Creates a BoxStore using the model definition from your
  /// `objectbox.g.dart` file in the given [directory] path
  /// (or if null the [defaultDirectoryPath]).
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
  /// final store = Store(getObjectBoxModel());
  /// ```
  ///
  /// See our examples for more details.
  Store(this._defs,
      {String? directory,
      int? maxDBSizeInKB,
      int? fileMode,
      int? maxReaders,
      bool queriesCaseSensitiveDefault = true,
      String? macosApplicationGroup})
      : _weak = false,
        _queriesCaseSensitiveDefault = queriesCaseSensitiveDefault,
        directoryPath = _safeDirectoryPath(directory),
        _absoluteDirectoryPath =
            path.context.canonicalize(_safeDirectoryPath(directory)) {
    try {
      if (Platform.isMacOS && macosApplicationGroup != null) {
        if (!macosApplicationGroup.endsWith('/')) {
          macosApplicationGroup += '/';
        }
        if (macosApplicationGroup.length > 20) {
          ArgumentError.value(macosApplicationGroup, 'macosApplicationGroup',
              'Must be at most 20 characters long');
        }
        final cStr = macosApplicationGroup.toNativeUtf8();
        try {
          C.posix_sem_prefix_set(cStr.cast());
        } finally {
          malloc.free(cStr);
        }
      }
      _checkStoreDirectoryNotOpen();
      final model = Model(_defs.model);

      final opt = C.opt();
      checkObxPtr(opt, 'failed to create store options');

      try {
        checkObx(C.opt_model(opt, model.ptr));
        final cStr = directoryPath.toNativeUtf8();
        try {
          checkObx(C.opt_directory(opt, cStr.cast()));
        } finally {
          malloc.free(cStr);
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
      if (debugLogs) {
        print('Opening store (C lib V${libraryVersion()})... path=$directory'
            ' isOpen=${isOpen(directory)}');
      }

      _cStore = C.store_open(opt);

      _checkStorePointer(_cStore);

      // Always create _reference, so it can be non-nullable.
      // Ensure we only try to access the store created in the same process.
      // Also serves as a simple sanity check/hash.
      _reference = ByteData(2 * _int64Size);
      _reference.setUint64(0 * _int64Size, pid);
      _reference.setUint64(1 * _int64Size, _ptr.address);

      _openStoreDirectories.add(_absoluteDirectoryPath);

      _attachFinalizer();
    } catch (e) {
      _reader.clear();
      rethrow;
    }
  }

  /// Create a Dart store instance from an existing native store [reference].
  ///
  /// Use this if you want to access the same store from multiple isolates.
  /// This results in two (or more) isolates having access to the same
  /// underlying native store. Concurrent access is ensured using implicit or
  /// explicit transactions.
  ///
  /// Note: make sure you don't use store in any of the isolates after the
  /// original store is closed (by calling [close]).
  ///
  /// To do this, you'd send the [reference] over a [SendPort], receive
  /// it in another isolate and pass it to [Store.fromReference].
  ///
  /// Example:
  /// ```dart
  /// // See test/isolates_test.dart for an actual working example.
  /// // Main isolate:
  ///   final store = Store(getObjectBoxModel())
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
  ///       store = Store.fromReference(getObjectBoxModel(), msg as ByteData);
  ///     }
  ///     ...
  ///   }
  /// ```
  Store.fromReference(this._defs, this._reference,
      {bool queriesCaseSensitiveDefault = true})
      // must not close the same native store twice so [_weak]=true
      : _weak = true,
        directoryPath = '',
        _absoluteDirectoryPath = '',
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

  /// Attach to a store opened in the [directoryPath]
  /// (or if null the [defaultDirectoryPath]).
  ///
  /// Use this to access an open store from other isolates.
  /// This results in each isolate having access to the same underlying native
  /// store.
  ///
  /// The returned store is a new instance (e.g. different pointer value) with
  /// its own lifetime and must also be closed (e.g. before an isolate exits).
  /// The actual underlying store is only closed when the last store instance
  /// is closed (e.g. when the app exits).
  Store.attach(this._defs, String? directoryPath,
      {bool queriesCaseSensitiveDefault = true})
      // _weak = false so store can be closed.
      : _weak = false,
        _queriesCaseSensitiveDefault = queriesCaseSensitiveDefault,
        directoryPath = _safeDirectoryPath(directoryPath),
        _absoluteDirectoryPath =
            path.context.canonicalize(_safeDirectoryPath(directoryPath)) {
    try {
      // Do not allow attaching to a store that is already open in the current
      // isolate. While technically possible this is not the intended usage
      // and e.g. transactions would have to be carefully managed to not
      // overlap.
      _checkStoreDirectoryNotOpen();

      final pathCStr = this.directoryPath.toNativeUtf8();
      try {
        if (debugLogs) {
          final isOpen = C.store_is_open(pathCStr.cast());
          print(
              'Attaching to store... path=${this.directoryPath} isOpen=$isOpen');
        }
        _cStore = C.store_attach(pathCStr.cast());
      } finally {
        malloc.free(pathCStr);
      }

      checkObxPtr(_cStore,
          'could not attach to the store at given path - please ensure it was opened before');

      // Not setting _reference as this is a replacement for obtaining a store
      // via reference.

      _attachFinalizer();
    } catch (e) {
      _reader.clear();
      rethrow;
    }
  }

  void _checkStoreDirectoryNotOpen() {
    if (_openStoreDirectories.contains(_absoluteDirectoryPath)) {
      throw UnsupportedError(
          'Cannot create multiple Store instances for the same directory in the same isolate. '
          'Please use a single Store, close() the previous instance before '
          'opening another one or attach to it in another isolate.');
    }
  }

  void _checkStorePointer(Pointer cStore) {
    try {
      checkObxPtr(cStore, 'failed to create store');
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
  }

  /// Attach a finalizer (using Dart C API) so when garbage collected, most
  /// importantly on Flutter's hot restart (not hot reload), the native Store is
  /// properly closed.
  ///
  /// During regular use it's still recommended to explicitly call
  /// close() and not rely on garbage collection [to avoid out-of-memory
  /// errors](https://github.com/dart-lang/language/issues/1847#issuecomment-1002751632).
  void _attachFinalizer() {
    initializeDartAPI();
    // Keep the finalizer so it can be detached when close() is called.
    _cFinalizer = C.dartc_attach_finalizer(
        this, native_store_close, _cStore.cast(), 1024 * 1024);
    if (_cFinalizer == nullptr) {
      close();
      throwLatestNativeError(context: 'attach store finalizer');
    }
  }

  /// Returns if an open store (i.e. opened before and not yet closed) was found
  /// for the given [directoryPath] (or if null the [defaultDirectoryPath]).
  static bool isOpen(String? directoryPath) {
    final path = _safeDirectoryPath(directoryPath);
    final cStr = path.toNativeUtf8();
    try {
      return C.store_is_open(cStr.cast());
    } finally {
      malloc.free(cStr);
    }
  }

  /// Returns a store reference you can use to create a new store instance with
  /// a single underlying native store. See [Store.fromReference] for more details.
  ByteData get reference => _reference;

  /// Returns if this store is already closed and can no longer be used.
  bool isClosed() => _cStore.address == 0;

  /// Closes this store.
  ///
  /// Don't try to call any other ObjectBox methods after the store is closed.
  void close() {
    if (isClosed()) return;

    _boxes.values.forEach(InternalBoxAccess.close);
    _boxes.clear();

    // Call each "onClose()" event listener.
    // Move the list to prevent "Concurrent modification during iteration".
    _onClose.values.toList(growable: false).forEach((listener) => listener());
    _onClose.clear();

    _reader.clear();

    if (!_weak) {
      _openStoreDirectories.remove(_absoluteDirectoryPath);
      final errors = List.filled(2, 0);
      if (_cFinalizer != nullptr) {
        errors[0] = C.dartc_detach_finalizer(_cFinalizer, this);
      }
      errors[1] = C.store_close(_cStore);
      errors.forEach(checkObx);
    }
    _cStore = nullptr;
  }

  /// Returns a cached Box instance.
  @pragma('vm:prefer-inline')
  Box<T> box<T>() {
    /// Note: see benchmark/bin/basics.dart BoxAccess* - HashMap is the winner.
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
  /// Aborts a transaction and rethrows on exception if [fn] is asynchronous.
  ///
  /// A transaction can group several operations into a single unit of work that
  /// either executes completely or not at all.
  /// The advantage of explicit transactions over the bulk put operations is
  /// that you can perform any number of operations and use objects of multiple
  /// boxes. In addition, you get a consistent (transactional) view on your data
  /// while the transaction is in progress.
  @pragma('vm:prefer-inline')
  R runInTransaction<R>(TxMode mode, R Function() fn) {
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

    return _runInTransaction(mode, (tx) => fn());
  }

  // Isolate entry point must be static or top-level.
  static Future<void> _callFunctionWithStoreInIsolate<P, R>(
      _IsoPass<P, R> isoPass) async {
    final store = Store.attach(isoPass.model, isoPass.dbDirectoryPath,
        queriesCaseSensitiveDefault: isoPass.queriesCaseSensitiveDefault);
    final result = await isoPass.runFn(store);
    store.close();
    // Note: maybe replace with Isolate.exit (and remove kill call in
    // runIsolated) once min Dart SDK 2.15.
    isoPass.resultPort?.send(result);
  }

  /// Spawns an isolate, runs [callback] in that isolate passing it [param] with
  /// its own Store and returns the result of callback.
  ///
  /// Instances of [callback] must be top-level functions or static methods
  /// of classes, not closures or instance methods of objects.
  ///
  /// Note: this requires Dart 2.15.0 or newer
  /// (shipped with Flutter 2.8.0 or newer).
  Future<R> runIsolated<P, R>(
      TxMode mode, FutureOr<R> Function(Store, P) callback, P param) async {
    final resultPort = ReceivePort();
    // Await isolate spawn to avoid waiting forever if it fails to spawn.
    final isolate = await Isolate.spawn(
        _callFunctionWithStoreInIsolate,
        _IsoPass(_defs, directoryPath, _queriesCaseSensitiveDefault,
            resultPort.sendPort, callback, param));
    // Use Completer to return result so type is not lost.
    final result = Completer<R>();
    resultPort.listen((dynamic message) {
      result.complete(message as R);
    });
    await result.future;
    resultPort.close();
    isolate.kill();
    return result.future;
  }

  /// Internal only - bypasses the main checks for async functions, you may
  /// only pass synchronous callbacks!
  R _runInTransaction<R>(TxMode mode, R Function(Transaction) fn) {
    final reused = _tx != null;
    final tx = reused ? _tx! : Transaction(this, mode);
    if (reused && tx.mode != TxMode.write && mode == TxMode.write) {
      throw UnsupportedError(
          'Cannot start a write transaction inside a read-only transaction.');
    }
    try {
      final result = fn(tx);
      if (!_nullSafetyEnabled && result is Future) {
        // Let's make sure users change their code not to use async.
        throw UnsupportedError(
            'Executing an "async" function in a transaction is not allowed.');
      }
      if (!reused) tx.successAndClose();
      return result;
    } catch (ex) {
      // Is a no-op if successAndClose did throw.
      if (!reused) tx.abortAndClose();
      rethrow;
    } finally {
      if (!reused) _tx = null;
    }
  }

  /// Return an existing SyncClient associated with the store or null if not
  /// available. Use [Sync.client()] to create one first.
  SyncClient? syncClient() => syncClientsStorage[this];

  /// Await for all (including future) async submissions to be completed
  /// (the async queue becomes idle for a moment).
  ///
  /// Returns true if all submissions were completed or async processing was
  /// not started; false if shutting down (or an internal error occurred).
  ///
  /// Use to wait until all puts by [Box.putQueued] have finished.
  bool awaitAsyncCompletion() {
    final result = C.store_await_async_submitted(_ptr);
    reachabilityFence(this);
    return result;
  }

  /// Await for previously submitted async operations to be completed
  /// (the async queue does not have to become idle).
  ///
  /// Returns true if all submissions were completed or async processing was
  /// not started; false if shutting down (or an internal error occurred).
  ///
  /// Use to wait until all puts by [Box.putQueued] have finished.
  bool awaitAsyncSubmitted() {
    final result = C.store_await_async_submitted(_ptr);
    reachabilityFence(this);
    return result;
  }

  /// The low-level pointer to this store.
  @pragma('vm:prefer-inline')
  Pointer<OBX_store> get _ptr =>
      isClosed() ? throw StateError('Store is closed') : _cStore;
}

/// Internal only.
@internal
class InternalStoreAccess {
  /// Access entity model for the given class (Dart Type).
  @pragma('vm:prefer-inline')
  static EntityDefinition<T> entityDef<T>(Store store) => store._entityDef();

  /// Internal helper to reuse a transaction object (and especially cursors).
  @pragma('vm:prefer-inline')
  static R runInTransaction<R>(
          Store store, TxMode mode, R Function(Transaction) fn) =>
      store._runInTransaction(mode, fn);

  /// Create a map from Entity ID to Entity type (dart class).
  static Map<int, Type> entityTypeById(Store store) {
    if (store._entityTypeById == null) {
      store._entityTypeById = HashMap<int, Type>();
      store._defs.bindings.forEach((Type entity, EntityDefinition entityDef) =>
          store._entityTypeById![entityDef.model.id.id] = entity);
    }
    return store._entityTypeById!;
  }

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

  /// The low-level pointer to this store.
  @pragma('vm:prefer-inline')
  static ReaderWithCBuffer reader(Store store) => store._reader;
}

const _int64Size = 8;

/// PathSet uses custom equals and hash function to canonically compare paths.
/// Note: this only works for a single isolate. Core would need to support the
/// same for the check to work across isolates.
final _openStoreDirectories = HashSet<String>();

/// True if the package enables null-safety (i.e. depends on SDK 2.12+).
/// Otherwise, it's we can distinguish at runtime whether a function is async.
final _nullSafetyEnabled = _nullReturningFn is! Future Function();
final _nullReturningFn = () => null;

/// Captures everything required to create a "copy" of a store in an isolate
/// and run user code.
@immutable
class _IsoPass<P, R> {
  final ModelDefinition model;

  /// Used to attach to store in separate isolate
  /// (may be replaced in the future).
  final String dbDirectoryPath;

  final bool queriesCaseSensitiveDefault;

  /// Non-void functions can use this port to receive the result.
  final SendPort? resultPort;

  /// Parameter passed to [callback].
  final P param;

  /// To be called in isolate.
  final FutureOr<R> Function(Store, P) callback;

  const _IsoPass(
      this.model,
      this.dbDirectoryPath,
      // ignore: avoid_positional_boolean_parameters
      this.queriesCaseSensitiveDefault,
      this.resultPort,
      this.callback,
      this.param);

  /// Calls [callback] inside this class so types are not lost
  /// (if called in isolate types would be dynamic instead of P and R).
  FutureOr<R> runFn(Store store) => callback(store, param);
}
