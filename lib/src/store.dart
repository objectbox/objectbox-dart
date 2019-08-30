import "dart:ffi";
import "dart:mirrors";

import "bindings/bindings.dart";
import "bindings/helpers.dart";

import "model.dart";

class Store {
    Pointer<Void> _objectboxStore;
    var _modelDescriptions;

    Store(var classes) {                        // TODO: allow setting options, e.g. database path
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

    getEntityDescriptionFromClass(cls) {
        final clsName = getSymbolName(reflectClass(cls).simpleName);
        final idx = _modelDescriptions.indexWhere((e) => e["entity"]["name"] == clsName);
        return idx == -1 ? null : _modelDescriptions[idx];
    }

    get ptr => _objectboxStore;
}
