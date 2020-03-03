import 'dart:ffi';
import 'signatures.dart';
import "package:ffi/ffi.dart" show allocate, free;

typedef bool dataVisitorCallback(Pointer<Uint8> dataPtr, int length);

int visitorId = 0;
final callbacks = <int, dataVisitorCallback>{};

int _forwarder(Pointer<Void> callbackId, Pointer<Uint8> dataPtr, int size) {
  if (callbackId == null) {
    throw Exception("Data-visitor callback issued with NULL user_data");
  }

  return callbacks[callbackId.cast<Int64>().value](dataPtr, size) ? 1 : 0;
}

/// A data visitor wrapper/forwarder to be used where obx_data_visitor is expected.
class DataVisitor {
  int _id;
  Pointer<Int64> _idPtr;

  Pointer<NativeFunction<obx_data_visitor_native_t>> get fn => Pointer.fromFunction(_forwarder, 0);

  Pointer<Void> get userData => _idPtr.cast<Void>();

  DataVisitor(dataVisitorCallback callback) {
    // cycle through ids until we find an empty slot
    visitorId++;
    var initialId = visitorId;
    while (callbacks.containsKey(visitorId)) {
      visitorId++;

      if (initialId == visitorId) {
        throw Exception("Data-visitor callbacks queue full - can't allocate another");
      }
    }
    // register the visitor
    _id = visitorId;
    callbacks[_id] = callback;

    _idPtr = allocate<Int64>();
    _idPtr.value = _id;
  }

  void close() {
    // unregister the visitor
    callbacks.remove(_id);
    free(_idPtr);
  }
}
