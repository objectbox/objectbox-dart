import "dart:ffi";

import "bindings/bindings.dart";
import "bindings/helpers.dart";
import "ffi/cstring.dart";

import "model.dart";

class Store {
    Pointer<Void> _objectboxStore;
    Map<Type, Map<String, dynamic>> _modelDefinitions = {};

    Store(List<List<dynamic>> defs, {String directory, int maxDBSizeInKB, int fileMode, int maxReaders}) {                        // TODO: allow setting options, e.g. database path
        defs.forEach((d) => _modelDefinitions[d[0]] = d[1]);
        var model = Model(defs.map((d) => d[1]["model"] as Map<String, dynamic>).toList());

        var opt = bindings.obx_opt();
        checkObxPtr(opt, "failed to create store options");

        try {
            checkObx(bindings.obx_opt_model(opt, model.ptr));
            if (directory != null && directory.length != 0) {
                var cStr = new CString(directory);
                try {
                    checkObx(bindings.obx_opt_directory(opt, cStr.ptr));
                } finally {
                    cStr.free();
                }
            }
            if (maxDBSizeInKB != null && maxDBSizeInKB > 0)
                bindings.obx_opt_max_db_size_in_kb(opt, maxDBSizeInKB);
            if (fileMode != null && fileMode >= 0)
                bindings.obx_opt_file_mode(opt, fileMode);
            if (maxReaders != null && maxReaders > 0)
                bindings.obx_opt_max_readers(opt, maxReaders);
        } catch(e) {
            bindings.obx_opt_free(opt);
            rethrow;
        }
        _objectboxStore = bindings.obx_store_open(opt);
        checkObxPtr(_objectboxStore, "failed to create store");
    }

    close() {
        checkObx(bindings.obx_store_close(_objectboxStore));
    }

    getEntityModelDefinitionFromClass(cls) {
        return _modelDefinitions[cls]["model"];
    }

    getEntityReaderFromClass<T>() {
        return _modelDefinitions[T]["reader"] as Map<String, dynamic> Function(T);
    }

    getEntityBuilderFromClass<T>() {
        return _modelDefinitions[T]["builder"] as T Function(Map<String, dynamic>);
    }

    get ptr => _objectboxStore;
}
