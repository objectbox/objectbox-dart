import "dart:ffi";

import "store.dart";
import "bindings/bindings.dart";
import "bindings/helpers.dart";

class Box<T> {
    Store _store;
    Pointer<Void> _objectboxBox;

    Box(this._store) {
        final entityId = _store.getEntityIdFromClass(T);
        check(entityId != -1);
        _objectboxBox = bindings.obx_box(_store.ptr, entityId);
        check(_objectboxBox != null);
        check(_objectboxBox.address != 0);
    }

    put(T inst) {

    }

    close() {
        if(_store != null) {
            _store.close();
            _store = null;
        }
    }

    get ptr => _objectboxBox;
}
