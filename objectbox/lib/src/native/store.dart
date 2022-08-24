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

  /// May be null for minimal store, access via [_modelDefinition] with null check.
  final ModelDefinition? _defs;
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

  /// If weak and calling [close] does not try to close the native Store and
  /// remove [_absoluteDirectoryPath] from [_openStoreDirectories].
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
  /// ## Case insensitive queries
  ///
  /// By default, ObjectBox queries are case sensitive. Set [queriesCaseSensitiveDefault]
  /// to `false` to make queries ignore case by default.
  ///
  /// Case sensitivity can also be set for each query.
  ///
  /// ## macOS application group
  ///
  /// If you're creating a sandboxed macOS app use [macosApplicationGroup] to
  /// specify the application group. For more details see our online docs.
  ///
  /// ## Maximum database size
  ///
  /// [maxDBSizeInKB] sets the maximum size the database file can grow to.
  /// By default this is 1 GB, which should be sufficient for most applications.
  /// The store will throw when trying to insert more data if the maximum size
  /// is reached.
  ///
  /// In general, a maximum size prevents the database from growing indefinitely
  /// when something goes wrong (for example data is put in an infinite loop).
  ///
  /// ## File mode
  ///
  /// Specify [unix-style file permissions](https://en.wikipedia.org/wiki/File_system_permissions#Numeric_notation)
  /// for database files with [fileMode]. E.g. for `-rw-r----` (owner, group,
  /// other) pass the octal code `0640`. Any newly generated directory
  /// additionally gets searchable (01) for groups with read or write permissions.
  /// It's not allowed to pass in an executable flag.
  ///
  /// ## Maximum number of readers
  ///
  /// [maxReaders] sets the maximum number of concurrent readers. For most
  /// applications, the default is fine (~ 126 readers).
  ///
  /// A "reader" is short for a thread involved in a read transaction.
  ///
  /// If the store throws OBX_ERROR_MAX_READERS_EXCEEDED, you should first worry
  /// about the amount of threads your code is using.
  /// For highly concurrent setups (e.g. using ObjectBox on the server side) it
  /// may make sense to increase the number.
  ///
  /// Note: Each thread that performed a read transaction and is still alive
  /// holds on to a reader slot. These slots only get vacated when the thread
  /// ends. Thus, be mindful with the number of active threads.
  ///
  /// ## Debug flags
  /// Pass one or more [DebugFlags] to [debugFlags] to enable debug log
  /// output:
  /// ```dart
  /// final store = Store(getObjectBoxModel(),
  ///     debugFlag: DebugFlags.logQueries | DebugFlags.logQueryParameters);
  /// ```
  ///
  /// See our examples for more details.
  Store(ModelDefinition modelDefinition,
      {String? directory,
      int? maxDBSizeInKB,
      int? fileMode,
      int? maxReaders,
      int? debugFlags,
      bool queriesCaseSensitiveDefault = true,
      String? macosApplicationGroup})
      : _defs = modelDefinition,
        _weak = false,
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
      final model = Model(modelDefinition.model);

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
        if (debugFlags != null) {
          C.opt_debug_flags(opt, debugFlags);
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

  /// Creates a Store clone with minimal functionality given a pointer address
  /// obtained by [_clone].
  ///
  /// Only has a reference to a native store, has no model definition. E.g. is
  /// good enough to start a transaction, but does not allow to use boxes.
  ///
  /// See [_clone] for details.
  Store._minimal(int ptrAddress, {bool queriesCaseSensitiveDefault = true})
      : _defs = null,
        _weak = false,
        directoryPath = '',
        _absoluteDirectoryPath = '',
        _queriesCaseSensitiveDefault = queriesCaseSensitiveDefault {
    if (ptrAddress == 0) {
      throw ArgumentError.value(
          ptrAddress, 'ptrAddress', 'Given native pointer address is invalid');
    }
    _cStore = Pointer<OBX_store>.fromAddress(ptrAddress);
    _attachFinalizer();
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

  /// Clones this native store and returns a pointer to the clone.
  ///
  /// The address of the pointer can be used with [Store._minimal].
  ///
  /// This can be useful to access the same Store in another isolate as it is
  /// not possible to send a [Store] to an isolate (Store contains Pointer which
  /// can not be sent, ModelDefinition contains Function which can only be sent
  /// on Dart SDK 2.15 or higher). Instead, send the pointer address returned by
  /// this and create a minimal store in the isolate. For limitations see
  /// [Store._minimal].
  ///
  /// Make sure to [close] the clone before the isolate exits. The native store
  /// remains open until all clones and the original Store are closed.
  ///
  /// ```dart
  /// // Clone the store and obtain its address, can be sent to an isolate.
  /// final storePtrAddress = InternalStoreAccess.clone(store).address;
  ///
  /// // Within an isolate create a minimal store.
  /// final store = InternalStoreAccess.createMinimal(isolateInit.storePtrAddress);
  /// try {
  ///   // Use the store.
  /// } finally {
  ///   store.close();
  /// }
  /// ```
  Pointer<OBX_store> _clone() {
    final ptr = checkObxPtr(C.store_clone(_ptr));
    reachabilityFence(this);
    return ptr;
  }

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
    final binding = _modelDefinition.bindings[T];
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

  /// Like [runAsync], but executes [callback] within a read or write
  /// transaction depending on [mode].
  ///
  /// See the documentation on [runAsync] for important usage details.
  ///
  /// The following example gets the name of a User object, deletes the object
  /// and returns the name within a write transaction:
  /// ```dart
  /// String? readNameAndRemove(Store store, int objectId) {
  ///   var box = store.box<User>();
  ///   final nameOrNull = box.get(objectId)?.name;
  ///   box.remove(objectId);
  ///   return nameOrNull;
  /// }
  /// await store.runInTransactionAsync(TxMode.write, readNameAndRemove, objectId);
  /// ```
  Future<R> runInTransactionAsync<R, P>(
          TxMode mode, TxAsyncCallback<R, P> callback, P param) =>
      runAsync(
          (Store store, P p) =>
              store.runInTransaction(mode, () => callback(store, p)),
          param);

  // Isolate entry point must be able to be sent via SendPort.send.
  // Must guarantee only a single result event is sent.
  // runAsync only handles a single event, any sent afterwards are ignored. E.g.
  // in case [Error] or [Exception] are thrown after the result is sent.
  static Future<void> _callFunctionWithStoreInIsolate<P, R>(
      _RunAsyncIsolateConfig<P, R> isoPass) async {
    final store = Store.attach(isoPass.model, isoPass.dbDirectoryPath,
        queriesCaseSensitiveDefault: isoPass.queriesCaseSensitiveDefault);
    dynamic result;
    try {
      final callbackResult = await isoPass.runCallback(store);
      result = _RunAsyncResult(callbackResult);
    } catch (error, stack) {
      result = _RunAsyncError(error, stack);
    } finally {
      store.close();
    }

    // Note: maybe replace with Isolate.exit (and remove kill() call in caller)
    // once min Dart SDK 2.15.
    isoPass.resultPort.send(result);
  }

  /// Spawns an isolate, runs [callback] in that isolate passing it [param] with
  /// its own Store and returns the result of callback.
  ///
  /// This is useful for ObjectBox operations that take longer than a few
  /// milliseconds, e.g. putting many objects, which would cause frame drops.
  /// If all operations can execute within a single transaction, prefer to use
  /// [runInTransactionAsync].
  ///
  /// The Store given to the callback does not have to be closed, it is closed
  /// by the worker isolate once the callback returns (or throws).
  ///
  /// The following example gets the name of a User object, deletes the object
  /// and returns the name:
  /// ```dart
  /// String? readNameAndRemove(Store store, int objectId) {
  ///   var box = store.box<User>();
  ///   final nameOrNull = box.get(objectId)?.name;
  ///   box.remove(objectId);
  ///   return nameOrNull;
  /// }
  /// await store.runAsync(readNameAndRemove, objectId);
  /// ```
  ///
  /// The [callback] must be a function that can be sent to an isolate: either a
  /// top-level function, static method or a closure that only captures objects
  /// that can be sent to an isolate.
  ///
  /// Warning: Due to
  /// [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983) a
  /// closure may capture more objects than expected, even if they are not
  /// directly used in the closure itself.
  ///
  /// The types `P` (type of the parameter to be passed to the callback) and
  /// `R` (type of the result returned by the callback) must be able to be sent
  /// to or received from an isolate. The same applies to errors originating
  /// from the callback.
  ///
  /// See [SendPort.send] for a discussion on which values can be sent to and
  /// received from isolates.
  ///
  /// Note: this requires Dart 2.15.0 or newer
  /// (shipped with Flutter 2.8.0 or newer).
  Future<R> runAsync<P, R>(RunAsyncCallback<P, R> callback, P param) async {
    final port = RawReceivePort();
    final completer = Completer<dynamic>();

    void _cleanup() {
      port.close();
    }

    port.handler = (dynamic message) {
      _cleanup();
      completer.complete(message);
    };

    final Isolate isolate;
    try {
      // Await isolate spawn to avoid waiting forever if it fails to spawn.
      isolate = await Isolate.spawn(
          _callFunctionWithStoreInIsolate,
          _RunAsyncIsolateConfig(_modelDefinition, directoryPath,
              _queriesCaseSensitiveDefault, port.sendPort, callback, param),
          errorsAreFatal: true,
          onError: port.sendPort,
          onExit: port.sendPort);
    } on Object {
      _cleanup();
      rethrow;
    }

    final dynamic response = await completer.future;
    // Replace with Isolate.exit in _callFunctionWithStoreInIsolate
    // once min SDK 2.15.
    isolate.kill();

    if (response == null) {
      throw RemoteError('Isolate exited without result or error.', '');
    }

    if (response is _RunAsyncResult) {
      // Success, return result.
      return response.result as R;
    } else if (response is List<dynamic>) {
      // See isolate.addErrorListener docs for message structure.
      assert(response.length == 2);
      await Future<Never>.error(RemoteError(
        response[0] as String,
        response[1] as String,
      ));
    } else {
      // Error thrown by callback.
      assert(response is _RunAsyncError);
      response as _RunAsyncError;

      await Future<Never>.error(
        response.error,
        response.stack,
      );
    }
  }

  /// Deprecated. Use [runAsync] instead. Will be removed in a future release.
  ///
  /// Spawns an isolate, runs [callback] in that isolate passing it [param] with
  /// its own Store and returns the result of callback.
  ///
  /// Instances of [callback] must be top-level functions or static methods
  /// of classes, not closures or instance methods of objects.
  ///
  /// Note: this requires Dart 2.15.0 or newer
  /// (shipped with Flutter 2.8.0 or newer).
  @Deprecated('Use `runAsync` instead. Will be removed in a future release.')
  Future<R> runIsolated<P, R>(TxMode mode,
          FutureOr<R> Function(Store, P) callback, P param) async =>
      runAsync(callback, param);

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

  /// Returns the ModelDefinition of this store, or throws if
  /// this is a minimal store.
  ModelDefinition get _modelDefinition {
    final model = _defs;
    if (model == null) throw StateError('Minimal store does not have a model');
    return model;
  }
}

/// Internal only.
@internal
class InternalStoreAccess {
  /// See [Store._clone].
  static Pointer<OBX_store> clone(Store store) => store._clone();

  /// See [Store._minimal].
  static Store createMinimal(int ptrAddress,
          {bool queriesCaseSensitiveDefault = true}) =>
      Store._minimal(ptrAddress,
          queriesCaseSensitiveDefault: queriesCaseSensitiveDefault);

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
      store._modelDefinition.bindings.forEach(
          (Type entity, EntityDefinition entityDef) =>
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

// Define type so IDE generates named parameters.
/// Signature for the callback passed to [Store.runAsync].
///
/// Instances must be functions that can be sent to an isolate.
typedef RunAsyncCallback<P, R> = FutureOr<R> Function(Store store, P parameter);

/// Captures everything required to create a "copy" of a store in an isolate
/// and run user code.
@immutable
class _RunAsyncIsolateConfig<P, R> {
  final ModelDefinition model;

  /// Used to attach to store in separate isolate
  /// (may be replaced in the future).
  final String dbDirectoryPath;

  final bool queriesCaseSensitiveDefault;

  /// Non-void functions can use this port to receive the result.
  final SendPort resultPort;

  /// Parameter passed to [callback].
  final P param;

  /// To be called in isolate.
  final RunAsyncCallback<P, R> callback;

  const _RunAsyncIsolateConfig(
      this.model,
      this.dbDirectoryPath,
      // ignore: avoid_positional_boolean_parameters
      this.queriesCaseSensitiveDefault,
      this.resultPort,
      this.callback,
      this.param);

  /// Calls [callback] inside this class so types are not lost
  /// (if called in isolate types would be dynamic instead of P and R).
  FutureOr<R> runCallback(Store store) => callback(store, param);
}

@immutable
class _RunAsyncResult<R> {
  final R result;

  const _RunAsyncResult(this.result);
}

@immutable
class _RunAsyncError {
  final Object error;
  final StackTrace stack;

  const _RunAsyncError(this.error, this.stack);
}

// Specify so IDE generates named parameters.
/// Signature for callback passed to [Store.runInTransactionAsync].
///
/// Instances must be functions that can be sent to an isolate.
typedef TxAsyncCallback<R, P> = R Function(Store store, P parameter);
