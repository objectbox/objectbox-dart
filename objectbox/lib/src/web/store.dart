// Web (stub) implementation of the store: mirrors the public API of
// `../native/store.dart` so the package compiles for the web platform, but
// throws `UnsupportedError` at runtime. See tracking issue #185.
// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:typed_data';

import '../box.dart';
import '../modelinfo/index.dart';
import '../store_config.dart';
import '../sync.dart';
import '../transaction.dart';
import 'unsupported.dart';

export '../store_config.dart';

/// Represents an ObjectBox database. Not supported on the web platform.
class Store {
  static const String defaultDirectoryPath = 'objectbox';

  static const String inMemoryPrefix = 'memory:';

  static bool debugLogs = false;

  String get directoryPath => throwUnsupportedOnWeb();

  Store(ModelDefinition modelDefinition,
      {String? directory,
      int? maxDBSizeInKB,
      int? maxDataSizeInKB,
      int? fileMode,
      int? maxReaders,
      int? debugFlags,
      bool queriesCaseSensitiveDefault = true,
      String? macosApplicationGroup}) {
    throwUnsupportedOnWeb();
  }

  Store.fromReference(ModelDefinition modelDefinition, ByteData reference,
      {bool queriesCaseSensitiveDefault = true}) {
    throwUnsupportedOnWeb();
  }

  Store.attach(ModelDefinition modelDefinition, String? directoryPath,
      {bool queriesCaseSensitiveDefault = true}) {
    throwUnsupportedOnWeb();
  }

  static String databaseVersion() => throwUnsupportedOnWeb();

  /// No store can currently be open on web, so this is always false.
  static bool isOpen(String? directoryPath) => false;

  static int dbFileSize(String? directoryPath) => throwUnsupportedOnWeb();

  static void removeDbFiles(String? directoryPath) => throwUnsupportedOnWeb();

  ByteData get reference => throwUnsupportedOnWeb();

  bool isClosed() => throwUnsupportedOnWeb();

  void close() => throwUnsupportedOnWeb();

  Box<T> box<T>() => throwUnsupportedOnWeb();

  R runInTransaction<R>(TxMode mode, R Function() fn) =>
      throwUnsupportedOnWeb();

  Future<R> runInTransactionAsync<R, P>(
          TxMode mode, TxAsyncCallback<R, P> callback, P param) =>
      throwUnsupportedOnWeb();

  Future<R> runAsync<P, R>(RunAsyncCallback<P, R> callback, P param) =>
      throwUnsupportedOnWeb();

  SyncClient? syncClient() => throwUnsupportedOnWeb();

  bool awaitQueueCompletion() => throwUnsupportedOnWeb();

  bool awaitQueueSubmitted() => throwUnsupportedOnWeb();
}

/// Web stub of the internal store API, see the native StoreInternal.
extension StoreInternal on Store {
  static Store attachByConfiguration(StoreConfiguration configuration) =>
      throwUnsupportedOnWeb();

  StoreConfiguration configuration() => throwUnsupportedOnWeb();

  void checkOpen() => throwUnsupportedOnWeb();
}

/// Internal only.
class InternalStoreAccess {
  static Store createMinimal(int ptrAddress,
          {bool queriesCaseSensitiveDefault = true}) =>
      throwUnsupportedOnWeb();

  static EntityDefinition<T> entityDef<T>(Store store) =>
      throwUnsupportedOnWeb();

  static R runInTransaction<R>(
          Store store, TxMode mode, R Function(Transaction) fn) =>
      throwUnsupportedOnWeb();

  static Map<int, Type> entityTypeById(Store store) => throwUnsupportedOnWeb();

  static void addCloseListener(
          Store store, dynamic key, void Function() listener) =>
      throwUnsupportedOnWeb();

  static void removeCloseListener(Store store, dynamic key) =>
      throwUnsupportedOnWeb();

  static bool queryCS(Store store) => throwUnsupportedOnWeb();
}

/// Web stub of the data change streams, see the native ObservableStore.
extension ObservableStore on Store {
  Stream<void> watch<EntityT>() => throwUnsupportedOnWeb();

  Stream<List<Type>> get entityChanges => throwUnsupportedOnWeb();
}

/// Signature for the callback passed to [Store.runAsync].
typedef RunAsyncCallback<P, R> = FutureOr<R> Function(Store store, P parameter);

/// Signature for callback passed to [Store.runInTransactionAsync].
typedef TxAsyncCallback<R, P> = R Function(Store store, P parameter);
