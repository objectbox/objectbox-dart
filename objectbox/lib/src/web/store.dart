// Web implementation of the store, backed by WebStoreEngine (in-memory,
// persisted to IndexedDB). See engine.dart for the design and semantics.
//
// Note for maintainers: web files import sibling web files directly (e.g.
// 'box.dart', not '../box.dart') - the analyzer resolves the conditional
// facades to the native variant, so referencing web-only members through a
// facade would not analyze.
// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../common.dart';
import '../modelinfo/index.dart';
import '../store_config.dart';
import '../sync.dart';
import '../transaction.dart' show TxMode;
import 'box.dart';
import 'engine.dart';
import 'transaction.dart';
import 'unsupported.dart';

export '../store_config.dart';

/// Represents an ObjectBox database on the web platform: an in-memory store
/// persisted to IndexedDB. Await [ready] before use (generated `openStore()`
/// does this for Flutter apps).
class Store {
  static const String defaultDirectoryPath = 'objectbox';

  static const String inMemoryPrefix = 'memory:';

  static bool debugLogs = false;

  /// Open engines by directory path (also the IndexedDB database name).
  static final Map<String, WebStoreEngine> _openEngines = {};

  /// Teardown futures of recently closed engines, so a re-open of the same
  /// path waits for the previous IndexedDB connection to flush and close.
  static final Map<String, Future<void>> _pendingCloses = {};

  final WebStoreEngine _engine;
  final Map<Type, Box> _boxes = {};
  bool _handleClosed = false;

  String get directoryPath => _engine.directoryPath;

  /// A future that completes when the store has loaded its persisted data
  /// and is ready for use.
  Future<void> get ready => _engine.ready;

  Store(ModelDefinition modelDefinition,
      {String? directory,
      int? maxDBSizeInKB,
      int? maxDataSizeInKB,
      int? fileMode,
      int? maxReaders,
      int? debugFlags,
      bool queriesCaseSensitiveDefault = true,
      String? macosApplicationGroup})
      // Note: sizes, file mode, readers and debug flags have no meaning on
      // web and are ignored.
      : _engine = _createEngine(modelDefinition,
            directory ?? defaultDirectoryPath, queriesCaseSensitiveDefault);

  static WebStoreEngine _createEngine(ModelDefinition modelDefinition,
      String path, bool queriesCaseSensitiveDefault) {
    if (_openEngines.containsKey(path)) {
      throw ObjectBoxException(
          'Cannot open store: another store is still open using the same path'
          ' "$path". Use Store.attach or close the other store first.');
    }
    final engine = WebStoreEngine(modelDefinition, path,
        queriesCaseSensitiveDefault: queriesCaseSensitiveDefault,
        awaitBeforeOpen: _pendingCloses[path]);
    _openEngines[path] = engine;
    return engine;
  }

  Store._fromEngine(this._engine);

  Store.fromReference(ModelDefinition modelDefinition, ByteData reference,
      {bool queriesCaseSensitiveDefault = true})
      : _engine = throwUnsupportedOnWeb();

  /// Attaches to an already open store (same JS thread only on web).
  factory Store.attach(ModelDefinition modelDefinition, String? directoryPath,
      {bool queriesCaseSensitiveDefault = true}) {
    final path = directoryPath ?? defaultDirectoryPath;
    final engine = _openEngines[path];
    if (engine == null) {
      throw ObjectBoxException(
          'Cannot attach to store: no store is open for path "$path"');
    }
    engine.refCount++;
    return Store._fromEngine(engine);
  }

  static String databaseVersion() => 'ObjectBox web (IndexedDB backed)';

  static bool isOpen(String? directoryPath) =>
      _openEngines.containsKey(directoryPath ?? defaultDirectoryPath);

  /// Approximate in-memory size of the stored records in bytes.
  static int dbFileSize(String? directoryPath) {
    final engine = _openEngines[directoryPath ?? defaultDirectoryPath];
    if (engine == null) return 0;
    var size = 0;
    for (final data in engine.entities.values) {
      for (final bytes in data.records.values) {
        size += bytes.lengthInBytes;
      }
    }
    return size;
  }

  /// Deletes the IndexedDB database. The store must be closed; the deletion
  /// is asynchronous (fire-and-forget, matching the synchronous native API).
  static void removeDbFiles(String? directoryPath) {
    final path = directoryPath ?? defaultDirectoryPath;
    if (_openEngines.containsKey(path)) {
      throw ObjectBoxException(
          'Cannot remove database files while the store is open');
    }
    if (path.startsWith(inMemoryPrefix)) return;
    final pending = _pendingCloses[path];
    if (pending != null) {
      pending.then((_) => web.window.indexedDB.deleteDatabase(path));
    } else {
      web.window.indexedDB.deleteDatabase(path);
    }
  }

  ByteData get reference => throwUnsupportedOnWeb();

  bool isClosed() => _handleClosed || _engine.isClosed;

  void close() {
    if (_handleClosed) return;
    _handleClosed = true;
    _boxes.clear();
    _engine.refCount--;
    if (_engine.refCount > 0) return;
    final path = _engine.directoryPath;
    _openEngines.remove(path);
    _engine.notifyCloseListeners();
    final closing = _engine.close();
    _pendingCloses[path] = closing;
    closing.whenComplete(() {
      if (identical(_pendingCloses[path], closing)) {
        _pendingCloses.remove(path);
      }
    });
  }

  Box<T> box<T>() {
    _checkOpen();
    return (_boxes[T] ??= InternalBoxAccess.create<T>(
        this, InternalStoreAccess.entityDef<T>(this))) as Box<T>;
  }

  R runInTransaction<R>(TxMode mode, R Function() fn) {
    _checkOpen();
    return _engine.runInTx(fn);
  }

  /// Runs [callback] within a transaction. Unlike on native platforms there
  /// are no isolates on web: the callback runs on the same thread.
  Future<R> runInTransactionAsync<R, P>(
          TxMode mode, TxAsyncCallback<R, P> callback, P param) =>
      Future.microtask(
          () => runInTransaction(mode, () => callback(this, param)));

  /// Runs [callback] asynchronously. Unlike on native platforms there are no
  /// isolates on web: the callback runs on the same thread.
  Future<R> runAsync<P, R>(RunAsyncCallback<P, R> callback, P param) =>
      Future.microtask(() async => await callback(this, param));

  /// There is no sync client on web (ObjectBox Sync is not available).
  SyncClient? syncClient() => null;

  /// On web, writes are persisted asynchronously (see engine.dart); this
  /// schedules the queue but cannot synchronously wait for it. Await
  /// [InternalStoreAccess.queueCompletion] (internal) or rely on the
  /// write-behind queue, which flushes within a microtask of every write.
  bool awaitQueueCompletion() => true;

  bool awaitQueueSubmitted() => true;

  void _checkOpen() {
    if (_handleClosed) throw StateError('Store is closed');
    _engine.checkOpen();
  }
}

/// Internal store API, mirroring the native StoreInternal extension.
extension StoreInternal on Store {
  static Store attachByConfiguration(StoreConfiguration configuration) {
    final engine = Store._openEngines[configuration.directoryPath];
    if (engine == null) {
      throw ObjectBoxException(
          'Cannot attach to store: no store is open for path'
          ' "${configuration.directoryPath}"');
    }
    engine.refCount++;
    return Store._fromEngine(engine);
  }

  StoreConfiguration configuration() => _engine.configuration;

  void checkOpen() => _checkOpen();
}

/// Internal only.
class InternalStoreAccess {
  static Store createMinimal(int ptrAddress,
          {bool queriesCaseSensitiveDefault = true}) =>
      throwUnsupportedOnWeb();

  /// The web engine backing [store]. Web-internal only.
  static WebStoreEngine engine(Store store) => store._engine;

  /// Completes when all currently queued writes are persisted to IndexedDB.
  static Future<void> queueCompletion(Store store) =>
      store._engine.awaitQueueCompletion();

  static EntityDefinition<T> entityDef<T>(Store store) {
    final definition = store._engine.modelDefinition.bindings[T];
    if (definition == null) {
      throw ArgumentError('Unknown entity type $T - is the model up to date?');
    }
    return definition as EntityDefinition<T>;
  }

  static R runInTransaction<R>(
      Store store, TxMode mode, R Function(Transaction) fn) {
    final tx = Transaction(store, mode);
    try {
      final result = fn(tx);
      tx.successAndClose();
      return result;
    } catch (e) {
      tx.abortAndClose();
      rethrow;
    }
  }

  static Map<int, Type> entityTypeById(Store store) => {
        for (final entry in store._engine.modelDefinition.bindings.entries)
          entry.value.model.id.id: entry.key
      };

  static void addCloseListener(
          Store store, dynamic key, void Function() listener) =>
      store._engine.closeListeners[key] = listener;

  static void removeCloseListener(Store store, dynamic key) =>
      store._engine.closeListeners.remove(key);

  static bool queryCS(Store store) =>
      store._engine.configuration.queriesCaseSensitiveDefault;
}

/// Data change streams, mirroring the native ObservableStore extension.
extension ObservableStore on Store {
  /// A stream that emits whenever objects of [EntityT] change (are put or
  /// removed). Query re-execution (like on native) is not yet available on
  /// web, so this emits void events.
  Stream<void> watch<EntityT>() => _engine.changes.stream
      .where((types) => types.contains(EntityT))
      .map<void>((_) {});

  /// A stream that emits the list of entity types affected by each committed
  /// change.
  Stream<List<Type>> get entityChanges => _engine.changes.stream;
}

/// Signature for the callback passed to [Store.runAsync].
typedef RunAsyncCallback<P, R> = FutureOr<R> Function(Store store, P parameter);

/// Signature for callback passed to [Store.runInTransactionAsync].
typedef TxAsyncCallback<R, P> = R Function(Store store, P parameter);
