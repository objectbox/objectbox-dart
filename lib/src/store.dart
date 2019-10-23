import "dart:ffi";

import "bindings/bindings.dart";
import "bindings/helpers.dart";
import "modelinfo/index.dart";

import "model.dart";

import "package:ffi/ffi.dart";

enum TxMode {
  Read,
  Write,
}

class Store {
  Pointer<Void> _cStore;
  Map<Type, EntityDefinition> _entityDefinitions = {};

  Store(List<EntityDefinition> defs, {String directory, int maxDBSizeInKB, int fileMode, int maxReaders}) {
    defs.forEach((d) => _entityDefinitions[d.type()] = d);
    var model = Model(defs.map((d) => d.getModel()).toList());

    var opt = bindings.obx_opt();
    checkObxPtr(opt, "failed to create store options");

    try {
      checkObx(bindings.obx_opt_model(opt, model.ptr));
      if (directory != null && directory.isNotEmpty) {
        var cStr = Utf8.toUtf8(directory).cast<Uint8>();
        try {
          checkObx(bindings.obx_opt_directory(opt, cStr));
        } finally {
          cStr.free();
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
    checkObxPtr(_cStore, "failed to create store");
  }

  close() {
    checkObx(bindings.obx_store_close(_cStore));
  }

  EntityDefinition<T> entityDef<T>() {
    return _entityDefinitions[T];
  }

  /// Executes a given function inside a transaction
  ///
  /// Returns type of [fn] if [return] is called in [fn]
  R runInTransaction<R>(TxMode mode, R Function() fn) {
    bool wanna_write = mode == TxMode.Write;
    Pointer<Void> txn = wanna_write ? bindings.obx_txn_write(_cStore) : bindings.obx_txn_read(_cStore);
    checkObxPtr(txn, "failed to create transaction");
    try {
      if (wanna_write) {
        checkObx(bindings.obx_txn_mark_success(txn, 1));
      }
      return fn();
    } on Exception {
      if (wanna_write) {
        checkObx(bindings.obx_txn_mark_success(txn, 0));
      }
      rethrow;
    } finally {
      checkObx(bindings.obx_txn_close(txn));
    }
  }

  get ptr => _cStore;
}
