import "store.dart";

class Box {
    Store _store;

    Box(classes) {
        _store = Store(classes);
    }

    close() {
        if(_store != null) {
            _store.close();
            _store = null;
        }
    }
}
