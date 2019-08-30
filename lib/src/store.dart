import "dart:ffi";
import "dart:mirrors";

import "bindings/bindings.dart";
import "bindings/helpers.dart";

import "model.dart";

class Store {
    Pointer<Void> _objectboxStore;
    var _modelDescriptions;

    Store(var classes) {
        var model = Model(classes);
        _modelDescriptions = model.desc;

        var opt = bindings.obx_opt();
        check(opt.address != 0);
        checkObx(bindings.obx_opt_model(opt, model.ptr));
        _objectboxStore = bindings.obx_store_open(opt);
        check(_objectboxStore != null);
        check(_objectboxStore.address != 0);
    }

    close() {
        checkObx(bindings.obx_store_close(_objectboxStore));
    }

    getEntityIdFromClass(cls) {
        final clsName = reflectClass(cls).simpleName.toString().split('"')[1];
        final idx = _modelDescriptions.indexWhere((e) => e["entity"]["name"] == clsName);
        return idx == -1 ? -1 : _modelDescriptions[idx]["entity"]["id"];
    }

    get ptr => _objectboxStore;
}
