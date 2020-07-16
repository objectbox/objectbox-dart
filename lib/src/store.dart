import "dart:ffi";
import "package:ffi/ffi.dart";
import "bindings/bindings.dart";
import "bindings/helpers.dart";
import "modelinfo/index.dart";
import "model.dart";
import "common.dart";

enum TxMode {
  Read,
  Write,
}

/// Represents an ObjectBox database and works together with [Box] to allow getting and putting Objects of
/// specific type.
class Store {
  Pointer<Void> _cStore;
  final ModelDefinition defs;

  Store(this.defs, {String directory, int maxDBSizeInKB, int fileMode, int maxReaders}) {
    var model = Model(defs.model);

    var opt = bindings.obx_opt();
    checkObxPtr(opt, "failed to create store options");

    try {
      checkObx(bindings.obx_opt_model(opt, model.ptr));
      if (directory != null && directory.isNotEmpty) {
        var cStr = Utf8.toUtf8(directory);
        try {
          checkObx(bindings.obx_opt_directory(opt, cStr));
        } finally {
          free(cStr);
        }
      }
      if (maxDBSizeInKB != null && maxDBSizeInKB > 0) bindings.obx_opt_max_db_size_in_kb(opt, maxDBSizeInKB);
      if (fileMode != null && fileMode >= 0) bindings.obx_opt_file_mode(opt, fileMode);
      if (maxReaders != null && maxReaders > 0) bindings.obx_opt_max_readers(opt, maxReaders);
    } catch (e) {
      bindings.obx_opt_free(opt);
      rethrow;
    }
    _cStore = bindings.obx_store_open(opt);

    try {
      checkObxPtr(_cStore, "failed to create store");
    } on ObjectBoxException catch (e) {
      // Recognize common problems when trying to open/create a database
      // 10199 = OBX_ERROR_STORAGE_GENERAL
      if (e.nativeCode == 10199 && e.nativeMsg != null && e.nativeMsg.contains('Dir does not exist')) {
        // 13 = permissions denied, 30 = read-only filesystem
        if (e.nativeMsg.endsWith(' (13)') || e.nativeMsg.endsWith(' (30)')) {
          final msg = e.nativeMsg +
              " - this usually indicates a problem with permissions; if you're using Flutter you may need to use " +
              "getApplicationDocumentsDirectory() from the path_provider package, see example/README.md";
          throw ObjectBoxException(dartMsg: e.dartMsg, nativeCode: e.nativeCode, nativeMsg: msg);
        }
      }
      rethrow;
    }
  }

  /// Closes this store.
  ///
  /// This method is useful for unit tests; most real applications should open a Store once and keep it open until
  /// the app dies.
  close() {
    checkObx(bindings.obx_store_close(_cStore));
  }

  EntityDefinition<T> entityDef<T>() {
    return defs.bindings[T];
  }

  /// Executes a given function inside a transaction.
  ///
  /// Returns type of [fn] if [return] is called in [fn].
  R runInTransaction<R>(TxMode mode, R Function() fn) {
    bool write = mode == TxMode.Write;
    Pointer<Void> txn = write ? bindings.obx_txn_write(_cStore) : bindings.obx_txn_read(_cStore);
    checkObxPtr(txn, "failed to create transaction");
    try {
      if (write) {
        checkObx(bindings.obx_txn_mark_success(txn, 1));
      }
      return fn();
    } catch (ex) {
      if (write) {
        checkObx(bindings.obx_txn_mark_success(txn, 0));
      }
      rethrow;
    } finally {
      checkObx(bindings.obx_txn_close(txn));
    }
  }

  /// The low-level pointer to this store.
  get ptr => _cStore;
}
