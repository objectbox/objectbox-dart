import 'dart:ffi';
import 'signatures.dart';
import "package:ffi/ffi.dart" show allocate, free;

/// This file implements C call forwarding using a trampoline approach.
///
/// When you want to pass a dart callback to a C function you cannot use lambdas and instead the callback must be
/// a static function, otherwise `Pointer.fromFunction()` called with your function won't compile.
/// Since static functions don't have any state, you must either rely on a global state or use a "userData" pointer
/// pass-through functionality provided by a C function.
///
/// The DataVisitor class tries to alleviate the burden of managing this and instead allows using lambdas from
/// user-code, internally mapping the C calls to the appropriate lambda.
///
/// Sample usage:
///   final results = <T>[];
///   final visitor = DataVisitor((Pointer<Uint8> dataPtr, int length) {
///     final bytes = dataPtr.asTypedList(length);
///     results.add(_fbManager.unmarshal(bytes));
///     return true; // return value usually indicates to the C function whether it should continue.
///   });
///
///   final err = bindings.obx_query_visit(_cQuery, visitor.fn, visitor.userData, offset, limit);
///   visitor.close(); // make sure to close the visitor, unregistering the callback it from the forwarder
///   checkObx(err);

int _lastId = 0;
final _callbacks = <int, bool Function(Pointer<Uint8> dataPtr, int length)>{};

// called from C, forwards calls to the actual callback registered at the given ID
int _forwarder(Pointer<Void> callbackId, Pointer<Uint8> dataPtr, int size) {
  if (callbackId == null || callbackId.address == 0) {
    throw Exception("Data-visitor callback issued with NULL user_data (callback ID)");
  }

  return _callbacks[callbackId.cast<Int64>().value](dataPtr, size) ? 1 : 0;
}

/// A data visitor wrapper/forwarder to be used where obx_data_visitor is expected.
class DataVisitor {
  int _id;
  Pointer<Int64> _idPtr;

  Pointer<NativeFunction<obx_data_visitor_native_t>> get fn => Pointer.fromFunction(_forwarder, 0);

  Pointer<Void> get userData => _idPtr.cast<Void>();

  DataVisitor(bool Function(Pointer<Uint8> dataPtr, int length) callback) {
    // cycle through ids until we find an empty slot
    _lastId++;
    var initialId = _lastId;
    while (_callbacks.containsKey(_lastId)) {
      _lastId++;

      if (initialId == _lastId) {
        throw Exception("Data-visitor callbacks queue full - can't allocate another");
      }
    }
    // register the visitor
    _id = _lastId;
    _callbacks[_id] = callback;

    _idPtr = allocate<Int64>();
    _idPtr.value = _id;
  }

  void close() {
    // unregister the visitor
    _callbacks.remove(_id);
    free(_idPtr);
  }
}
