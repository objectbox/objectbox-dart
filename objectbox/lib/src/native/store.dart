library store;

import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

import '../common.dart';
import '../modelinfo/index.dart';
import '../transaction.dart';
import '../util.dart';
import 'bindings/bindings.dart';
import 'bindings/helpers.dart';
import 'box.dart';
import 'model.dart';
import 'sync.dart';
import 'version.dart';

part 'observable.dart';

part 'store_config.dart';

/// Represents an ObjectBox database and works together with [Box] to allow
/// getting and putting.
class Store implements Finalizable {
  /// Path of the default directory, currently 'objectbox'.
  static const String defaultDirectoryPath = 'objectbox';

  /// Pass this together with a String identifier as the directory path to use
  /// a file-less in-memory database.
  static const String inMemoryPrefix = 'memory:';

  /// Enables a couple of debug logs.
  /// This meant for tests only; do not enable for releases!
  static bool debugLogs = false;

  /// Pointer to the C instance of this, access via [_ptr] with closed check.
  late Pointer<OBX_store> _cStore;

  /// Runs native close function on [_cStore] if this is garbage collected.
  ///
  /// Keeps the finalizer itself reachable (static), otherwise it might be
  /// disposed of before the finalizer callback gets a chance to run.
  static final _finalizer = NativeFinalizer(C.addresses.store_close.cast());

  HashMap<int, Type>? _entityTypeById;
  final _boxes = HashMap<Type, Box>();

  /// Configuration of this.
  /// Is null if this is a minimal store.
  /// Can be used with [Store._attachByConfiguration].
  late final StoreConfiguration? _configuration;

  Stream<List<Type>>? _entityChanges;

  final _readPointers = ReadPointers();
  Transaction? _tx;

  /// Path to the database directory.
  String get directoryPath {
    final configuration = _configuration;
    if (configuration != null) {
      return configuration.directoryPath;
    } else {
      throw StateError("A minimal store does not have a directory path.");
    }
  }

  /// Absolute path to the database directory, used for open check.
  /// For an in-memory database just the [inMemoryPrefix] and identifier.
  final String _absoluteDirectoryPath;

  late final ByteData _reference;

  /// A list of observers of the [Store.close] event.
  final _onClose = <dynamic, void Function()>{};

  /// If true and calling [close] will also close the native Store and
  /// remove [_absoluteDirectoryPath] from [_openStoreDirectories].
  final bool _closesNativeStore;

  static String _safeDirectoryPath(String? path) =>
      (path == null || path.isEmpty) ? defaultDirectoryPath : path;

  /// Like [_safeDirectoryPath], but returns an absolute path if [dbPath] is not
  /// prefixed with [inMemoryPrefix] to use with [_absoluteDirectoryPath].
  static String _safeAbsoluteDirectoryPath(String? dbPath) {
    final safePath = _safeDirectoryPath(dbPath);
    return safePath.startsWith(inMemoryPrefix)
        ? safePath
        : path.context.canonicalize(safePath);
  }

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
  /// ## In-memory database
  /// To use a file-less in-memory database, instead of a directory path pass
  /// `memory:` together with an identifier string as the [directory]:
  /// ```dart
  /// final inMemoryStore =
  ///     Store(getObjectBoxModel(), directory: "memory:test-db");
  /// ```
  ///
  /// ## Case insensitive queries
  ///
  /// By default, ObjectBox queries are case sensitive. Set [queriesCaseSensitiveDefault]
  /// to `false` to make queries ignore case by default.
  ///
  /// Case sensitivity can also be set for each query.
  ///
  /// ## Sandboxed macOS apps
  ///
  /// To use ObjectBox in a sandboxed macOS app, [create an app group](https://developer.apple.com/documentation/xcode/configuring-app-groups)
  /// and pass the ID to [macosApplicationGroup].
  ///
  /// Note: due to limitations in macOS the ID can be at most 19 characters long.
  ///
  /// By convention, the ID is `<Developer team ID>.<group name>`.
  ///
  /// You can verify the ID is correctly configured, by checking that the
  /// `macos/Runner/*.entitlements` files contain the relevant key and value,
  /// for example:
  ///
  /// ```
  /// <dict>
  ///   <key>com.apple.security.application-groups</key>
  ///   <array>
  ///     <string>FGDTDLOBXDJ.demo</string>
  ///   </array>
  /// </dict>
  /// ```
  ///
  /// This is required to enable additional interprocess communication (IPC),
  /// like POSIX semaphores, used by mutexes in the ObjectBox database library
  /// for macOS. Specifically, macOS requires that semaphore names are prefixed
  /// with an application group ID.
  ///
  /// ## Maximum database size
  ///
  /// [maxDBSizeInKB] sets the maximum size the database file can grow to.
  /// When applying a transaction (e.g. putting an object) would exceed it a
  /// [DbFullException] is thrown.
  ///
  /// By default, this is 1 GB, which should be sufficient for most applications.
  /// In general, a maximum size prevents the database from growing indefinitely
  /// when something goes wrong (for example data is put in an infinite loop).
  ///
  /// This value can be changed, so increased or also decreased, each time when
  /// opening a store.
  ///
  /// ## Maximum data size
  ///
  /// [maxDataSizeInKB] sets the maximum size the data stored in the database
  /// can grow to. When applying a transaction (e.g. putting an object) would
  /// exceed it a [DbMaxDataSizeExceededException] is thrown.
  ///
  /// Must be below [maxDBSizeInKB].
  ///
  /// Different from [maxDBSizeInKB] this only counts bytes stored in objects,
  /// excluding system and metadata. However, it is more involved than database
  /// size tracking, e.g. it stores an internal counter. Only use this if a
  /// stricter, more accurate limit is required.
  ///
  /// When the data limit is reached, data can be removed to get below the limit
  /// again (assuming the database size limit is not also reached).
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
  /// applications, the default is fine (about 126 readers).
  ///
  /// A "reader" is short for a thread involved in a read transaction. If the
  /// maximum is exceeded the store throws [DbMaxReadersExceededException]. In
  /// this case check that your code only uses a reasonable amount of threads.
  ///
  /// For highly concurrent setups (e.g. you are using ObjectBox on the server
  /// side) it may make sense to increase the number.
  ///
  /// Note: Each thread that performed a read transaction and is still alive
  /// holds on to a reader slot. These slots only get vacated when the thread
  /// ends. Thus, be mindful with the number of active threads.
  ///
  /// ## Debug flags
  ///
  /// Pass one or more [DebugFlags] to [debugFlags] to enable debug log
  /// output:
  ///
  /// ```dart
  /// final store = Store(getObjectBoxModel(),
  ///     debugFlag: DebugFlags.logQueries | DebugFlags.logQueryParameters);
  /// ```
  ///
  /// Note: to see these log messages when debugging an iOS app, you need to
  /// open `ios/Runner.xcworkspace` in Xcode and run the app from there.
  /// See also the Flutter instructions to
  /// ["Debug Dart and iOS code using Xcode"](https://docs.flutter.dev/testing/native-debugging#debug-dart-and-ios-code-using-xcode).
  ///
  /// ## More details
  ///
  /// See our [documentation](https://docs.objectbox.io/) and examples for more
  /// details.
  Store(ModelDefinition modelDefinition,
      {String? directory,
      int? maxDBSizeInKB,
      int? maxDataSizeInKB,
      int? fileMode,
      int? maxReaders,
      int? debugFlags,
      bool queriesCaseSensitiveDefault = true,
      String? macosApplicationGroup})
      : _closesNativeStore = true,
        _absoluteDirectoryPath = _safeAbsoluteDirectoryPath(directory) {
    try {
      if (macosApplicationGroup != null) {
        final isGroupEmpty = macosApplicationGroup.isEmpty;
        // Docs don't explicitly require a trailing slash, so add one if missing
        if (!macosApplicationGroup.endsWith('/')) {
          macosApplicationGroup += '/';
        }
        // The database library would check for length, but refers to 'prefix'
        // instead of the parameter name used here. So duplicate the checks.
        if (isGroupEmpty || macosApplicationGroup.length > 20) {
          throw ArgumentError.value(
              macosApplicationGroup,
              'macosApplicationGroup',
              'Must be at least 1 and at most 19 characters long');
        }
        // This is required to enable additional interprocess communication
        // (IPC) in sandboxed apps (https://developer.apple.com/documentation/xcode/configuring-app-groups),
        // like POSIX semaphores, used by mutexes in the ObjectBox database
        // library. macOS requires that semaphore names are prefixed with an
        // application group ID.
        // See the constructor docs for more details.
        // Note: calling this on all platforms is fine, it will be a no-op if
        // not supported.
        checkObx(
            withNativeString(macosApplicationGroup, C.posix_sem_prefix_set));
      }
      _checkStoreDirectoryNotOpen();
      final model = Model(modelDefinition.model);
      final safeDirectoryPath = _safeDirectoryPath(directory);

      final opt = C.opt();
      checkObxPtr(opt, 'failed to create store options');

      try {
        checkObx(C.opt_model(opt, model.ptr));
        checkObx(withNativeString(
            safeDirectoryPath, (cStr) => C.opt_directory(opt, cStr)));
        if (maxDBSizeInKB != null && maxDBSizeInKB > 0) {
          C.opt_max_db_size_in_kb(opt, maxDBSizeInKB);
        }
        if (maxDataSizeInKB != null && maxDataSizeInKB > 0) {
          C.opt_max_data_size_in_kb(opt, maxDataSizeInKB);
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
        print(
            "Opening store (C lib V${libraryVersion()})... path=$safeDirectoryPath"
            " isOpen=${isOpen(safeDirectoryPath)}");
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
      _attachConfiguration(_cStore, modelDefinition, safeDirectoryPath,
          queriesCaseSensitiveDefault);
      _attachFinalizer();
    } catch (e) {
      _readPointers.clear();
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
  Store.fromReference(ModelDefinition modelDefinition, this._reference,
      {bool queriesCaseSensitiveDefault = true})
      :
        // Must not close native store twice, only original store is allowed to.
        _closesNativeStore = false,
        _absoluteDirectoryPath = '' {
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

    _attachConfiguration(
        _cStore, modelDefinition, '', queriesCaseSensitiveDefault);
  }

  /// Creates a Store clone with minimal functionality given a pointer address
  /// obtained by [_clone].
  ///
  /// Only has a reference to a native store, has no model definition. E.g. is
  /// good enough to start a transaction, but does not allow to use boxes.
  ///
  /// See [_clone] for details.
  Store._minimal(int ptrAddress, {bool queriesCaseSensitiveDefault = true})
      : _closesNativeStore = true,
        _absoluteDirectoryPath = '' {
    if (ptrAddress == 0) {
      throw ArgumentError.value(
          ptrAddress, 'ptrAddress', 'Given native pointer address is invalid');
    }
    _cStore = Pointer<OBX_store>.fromAddress(ptrAddress);
    _configuration = null;
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
  Store.attach(ModelDefinition modelDefinition, String? directoryPath,
      {bool queriesCaseSensitiveDefault = true})
      : _closesNativeStore = true,
        _absoluteDirectoryPath = _safeAbsoluteDirectoryPath(directoryPath) {
    try {
      // Do not allow attaching to a store that is already open in the current
      // isolate. While technically possible this is not the intended usage
      // and e.g. transactions would have to be carefully managed to not
      // overlap.
      _checkStoreDirectoryNotOpen();

      final safeDirectoryPath = _safeDirectoryPath(directoryPath);
      withNativeString(safeDirectoryPath, (cStr) {
        if (debugLogs) {
          final isOpen = C.store_is_open(cStr);
          print('Attaching to store... path=$safeDirectoryPath isOpen=$isOpen');
        }
        _cStore = C.store_attach(cStr);
      });

      checkObxPtr(_cStore,
          'could not attach to the store at given path - please ensure it was opened before');

      // Not setting _reference as this is a replacement for obtaining a store
      // via reference.

      _attachConfiguration(_cStore, modelDefinition, safeDirectoryPath,
          queriesCaseSensitiveDefault);
      _attachFinalizer();
    } catch (e) {
      _readPointers.clear();
      rethrow;
    }
  }

  /// Attach to an open Store for short-time use.
  ///
  /// Will throw if the underlying store is already closed.
  ///
  /// While this is open will prevent the underlying store from closing,
  /// so [close] this immediately when done using. Closing this will only close
  /// the underlying store if it is not opened elsewhere.
  Store._attachByConfiguration(StoreConfiguration configuration)
      : _closesNativeStore = true,
        _absoluteDirectoryPath = '' {
    try {
      Pointer<OBX_store>? storePtr = C.store_attach_id(configuration.id);
      _checkStorePointer(storePtr);
      _cStore = storePtr;
      _configuration = configuration;
      _attachFinalizer();
    } catch (e) {
      _readPointers.clear();
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
        // ignore: prefer_interpolation_to_compose_strings
        throw ObjectBoxException(e.message +
            ' - this usually indicates a problem with permissions; '
                "if you're using Flutter you may need to use "
                'getApplicationDocumentsDirectory() from the path_provider '
                'package, see example/README.md');
      }
      rethrow;
    }
  }

  void _attachConfiguration(Pointer<OBX_store> storePtr, ModelDefinition model,
      String directoryPath, bool queriesCaseSensitiveDefault) {
    int id = C.store_id(storePtr);
    _configuration = StoreConfiguration._(
        id, model, directoryPath, queriesCaseSensitiveDefault);
  }

  /// Attach a finalizer (using Dart C API) so when garbage collected, most
  /// importantly on Flutter's hot restart (not hot reload), the native Store is
  /// properly closed.
  ///
  /// During regular use it's still recommended to explicitly call
  /// close() and not rely on garbage collection [to avoid out-of-memory
  /// errors](https://github.com/dart-lang/language/issues/1847#issuecomment-1002751632).
  void _attachFinalizer() {
    _finalizer.attach(this, _cStore.cast(),
        detach: this, externalSize: 200 * 1024);
  }

  /// Returns the version and features of the platform-specific ObjectBox
  /// database library.
  ///
  /// The format may change in any future release, only use this for
  /// informational purposes.
  static String databaseVersion() => dartStringFromC(C.version_core_string());

  /// Returns if an open store (i.e. opened before and not yet closed) was found
  /// for the given [directoryPath].
  ///
  /// For Flutter apps, the default [directoryPath] can be obtained with
  /// `(await defaultStoreDirectory()).path` from `objectbox_flutter_libs`
  /// (or `objectbox_sync_flutter_libs`).
  ///
  /// For Dart Native apps, pass null to use the [defaultDirectoryPath].
  static bool isOpen(String? directoryPath) {
    final path = _safeDirectoryPath(directoryPath);
    return withNativeString(path, C.store_is_open);
  }

  /// Returns the file size in bytes of the main database file for the given
  /// [directoryPath], or 0 if the file does not exist or some error occurred.
  ///
  /// For in-memory databases, it is supported to pass the [inMemoryPrefix] and
  /// the identifier. The rough size in bytes of the in-memory database will be
  /// reported instead.
  ///
  /// For Flutter apps, the default [directoryPath] can be obtained with
  /// `(await defaultStoreDirectory()).path` from `objectbox_flutter_libs`
  /// (or `objectbox_sync_flutter_libs`).
  ///
  /// For Dart Native apps, pass null to use the [defaultDirectoryPath].
  static int dbFileSize(String? directoryPath) {
    final path = _safeDirectoryPath(directoryPath);
    return withNativeString(path, C.db_file_size);
  }

  /// Danger zone! This will delete all files in the given directory!
  ///
  /// If an in-memory database identifier is given (using [inMemoryPrefix]),
  /// this will just clean up the in-memory database.
  ///
  /// No [Store] may be alive using the given [directoryPath]. This means this
  /// should be called before creating a store.
  ///
  /// For Flutter apps, the default [directoryPath] can be obtained with
  /// `(await defaultStoreDirectory()).path` from `objectbox_flutter_libs`
  /// (or `objectbox_sync_flutter_libs`).
  ///
  /// For Dart Native apps, pass null to use the [defaultDirectoryPath].
  static void removeDbFiles(String? directoryPath) {
    final path = _safeDirectoryPath(directoryPath);
    checkObx(withNativeString(path, C.remove_db_files));
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
  Pointer<OBX_store> _clone() => checkObxPtr(C.store_clone(_ptr));

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

    _readPointers.clear();

    if (_closesNativeStore) {
      _openStoreDirectories.remove(_absoluteDirectoryPath);
      _finalizer.detach(this);
      checkObx(C.store_close(_cStore));
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
    final binding = configuration().modelDefinition.bindings[T];
    if (binding == null) {
      throw ArgumentError('Unknown entity type $T');
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
    if (fn is Future Function()) {
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
    final store = Store._attachByConfiguration(isoPass.storeConfiguration);
    dynamic result;
    try {
      final callbackResult = await isoPass.runCallback(store);
      result = _RunAsyncResult(callbackResult);
    } catch (error, stack) {
      result = _RunAsyncError(error, stack);
    } finally {
      store.close();
    }
    Isolate.exit(isoPass.resultPort, result);
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
  Future<R> runAsync<P, R>(RunAsyncCallback<P, R> callback, P param) async {
    final port = RawReceivePort();
    final completer = Completer<dynamic>();

    void cleanup() {
      port.close();
    }

    port.handler = (dynamic message) {
      cleanup();
      completer.complete(message);
    };

    try {
      // Await isolate spawn to avoid waiting forever if it fails to spawn.
      await Isolate.spawn(
          _callFunctionWithStoreInIsolate<P, R>,
          _RunAsyncIsolateConfig(
              configuration(), port.sendPort, callback, param),
          errorsAreFatal: true,
          onError: port.sendPort,
          onExit: port.sendPort);
    } on Object {
      cleanup();
      rethrow;
    }

    final dynamic response = await completer.future;
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

  /// Await for all (including future) submissions using [Box.putQueued] to be
  /// completed (the queue becomes idle for a moment).
  ///
  /// Returns true if all submissions were completed or processing was
  /// not started; false if shutting down (or an internal error occurred).
  ///
  /// Use to wait until all puts by [Box.putQueued] have finished.
  bool awaitQueueCompletion() => C.store_await_async_completion(_ptr);

  /// Await for previously submitted operations using [Box.putQueued] to be
  /// completed (the queue does not have to become idle).
  ///
  /// Returns true if all submissions were completed or processing was
  /// not started; false if shutting down (or an internal error occurred).
  ///
  /// Use to wait until all puts by [Box.putQueued] have finished.
  bool awaitQueueSubmitted() => C.store_await_async_submitted(_ptr);

  /// The low-level pointer to this store.
  @pragma('vm:prefer-inline')
  Pointer<OBX_store> get _ptr {
    checkOpen();
    return _cStore;
  }
}

/// Internal class to provide re-usable pointers for reading data. This avoids
/// expensive allocation by only allocating the pointers once for the lifetime
/// of the store.
///
/// [clear] once done using to free native resources (pointer memory).
class ReadPointers {
  /// Pointer to use for data.
  final Pointer<Pointer<Uint8>> dataPtrPtr = malloc();

  /// Pointer to use for size of data.
  final Pointer<Size> sizePtr = malloc();

  /// Free native resources (pointer memory).
  /// Pointers can not longer be used afterwards.
  void clear() {
    malloc.free(dataPtrPtr);
    malloc.free(sizePtr);
  }
}

/// This hides away methods from the public API
/// (this is not marked as show in objectbox.dart)
/// while remaining accessible by other libraries in this package.
extension StoreInternal on Store {
  /// See [Store._attachByConfiguration].
  static Store attachByConfiguration(StoreConfiguration configuration) =>
      Store._attachByConfiguration(configuration);

  /// Returns the configuration for this to be used with
  /// [Store._fromConfiguration()], valid while the underlying store is open.
  ///
  /// This will throw when called for a minimal store.
  StoreConfiguration configuration() {
    final config = _configuration;
    if (config == null) {
      throw StateError("This store does not provide a configuration.");
    } else {
      return config;
    }
  }

  /// If the store [isClosed] will throw an error.
  void checkOpen() {
    if (isClosed()) {
      throw StateError('Store is closed');
    }
  }

  /// Get re-usable data and size pointers for reading.
  ///
  /// Valid until the store is closed.
  /// Avoids expensive pointer allocation for each read.
  ///
  /// See [ReadPointers].
  ReadPointers readPointers() => _readPointers;
}

/// Internal only.
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
      store.configuration().modelDefinition.bindings.forEach(
          (Type entity, EntityDefinition entityDef) =>
              store._entityTypeById![entityDef.model.id.id] = entity);
    }
    return store._entityTypeById!;
  }

  /// Adds a listener to the [Store.close] event.
  static void addCloseListener(
          Store store, dynamic key, void Function() listener) =>
      store._onClose[key] = listener;

  /// Removes a [Store.close] event listener.
  static void removeCloseListener(Store store, dynamic key) =>
      store._onClose.remove(key);

  /// The low-level pointer to this store.
  @pragma('vm:prefer-inline')
  static Pointer<OBX_store> ptr(Store store) => store._ptr;

  /// String query case-sensitive default
  @pragma('vm:prefer-inline')
  static bool queryCS(Store store) =>
      store.configuration().queriesCaseSensitiveDefault;
}

const _int64Size = 8;

/// PathSet uses custom equals and hash function to canonically compare paths.
/// Note: this only works for a single isolate. Core would need to support the
/// same for the check to work across isolates.
final _openStoreDirectories = HashSet<String>();

// Define type so IDE generates named parameters.
/// Signature for the callback passed to [Store.runAsync].
///
/// Instances must be functions that can be sent to an isolate.
typedef RunAsyncCallback<P, R> = FutureOr<R> Function(Store store, P parameter);

/// Captures everything required to create a "copy" of a store in an isolate
/// and run user code.
@immutable
class _RunAsyncIsolateConfig<P, R> {
  final StoreConfiguration storeConfiguration;

  /// Non-void functions can use this port to receive the result.
  final SendPort resultPort;

  /// Parameter passed to [callback].
  final P param;

  /// To be called in isolate.
  final RunAsyncCallback<P, R> callback;

  const _RunAsyncIsolateConfig(
      this.storeConfiguration, this.resultPort, this.callback, this.param);

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
