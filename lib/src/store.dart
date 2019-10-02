import "dart:ffi";

import "bindings/bindings.dart";
import "bindings/helpers.dart";
import "modelinfo/index.dart";

import "model.dart";

import "package:ffi/ffi.dart";

class Store {
  Pointer<Void> _objectboxStore;
  Map<Type, Map<String, dynamic>> _modelDefinitions = {};

  Store(List<List<dynamic>> defs, {String directory, int maxDBSizeInKB, int fileMode, int maxReaders}) {
    defs.forEach((d) => _modelDefinitions[d[0]] = d[1]);
    var model = Model(defs.map((d) => d[1]["getModelEntity"]() as ModelEntity).toList());

    var opt = bindings.obx_opt();
    checkObxPtr(opt, "failed to create store options");

    try {
      checkObx(bindings.obx_opt_model(opt, model.ptr));
      if (directory != null && directory.length != 0) {
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
    _objectboxStore = bindings.obx_store_open(opt);
    checkObxPtr(_objectboxStore, "failed to create store");
  }

  close() {
    checkObx(bindings.obx_store_close(_objectboxStore));
  }

  ModelEntity getModelEntityFromClass(cls) {
    return _modelDefinitions[cls]["getModelEntity"]();
  }

  getEntityBuilderFromClass<T>() {
    return _modelDefinitions[T]["convertMapToInstance"] as T Function(Map<String, dynamic>);
  }

  getEntityReaderFromClass<T>() {
    return _modelDefinitions[T]["convertInstanceToMap"] as Map<String, dynamic> Function(T);
  }

  get ptr => _objectboxStore;
}
