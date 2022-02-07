import 'dart:ffi';

import '../../modelinfo/entity_definition.dart';
import '../store.dart';
import 'bindings.dart';

// ignore_for_file: public_member_api_docs

/// When you want to pass a dart callback to a C function you cannot use lambdas
/// and instead the callback must be a static function - giving a lambda to
/// [Pointer.fromFunction()] won't compile:
///      Error: fromFunction expects a static function as parameter.
///      dart:ffi only supports calling static Dart functions from native code.
///
/// With Dart being all synchronous and not sharing memory at all within a
/// single isolate, we can just alter a single global callback variable.
/// Therefore, let's have a single static function [_forwarder] converted to a
/// native visitor pointer [_nativeVisitor], calling [_callback] in the end.

bool Function(Pointer<Uint8> data, int size) _callback = _callback;

int _forwarder(Pointer<Void> _, Pointer<Void> dataPtr, int size) =>
    _callback(dataPtr.cast<Uint8>(), size) ? 1 : 0;

final Pointer<NativeFunction<obx_data_visitor>> _nativeVisitor =
    Pointer.fromFunction(_forwarder, 0);

/// The callback for reading data one-by-one.
///
/// - [data] is the read data buffer.
/// - [size] specifies the length of the read data.
/// - Return true to keep going, false to cancel.
@pragma('vm:prefer-inline')
Pointer<NativeFunction<obx_data_visitor>> dataVisitor(
    bool Function(Pointer<Uint8> data, int size) callback) {
  _callback = callback;
  return _nativeVisitor;
}

@pragma('vm:prefer-inline')
Pointer<NativeFunction<obx_data_visitor>> objectCollector<T>(
        List<T> list,
        Store store,
        EntityDefinition<T> entity,
        ObjectCollectorError outError) =>
    dataVisitor((Pointer<Uint8> data, int size) {
      try {
        list.add(entity.objectFromFB(
            store, InternalStoreAccess.reader(store).access(data, size)));
        return true;
      } catch (e) {
        outError.error = e;
        return false;
      }
    });

class ObjectCollectorError {
  Object? error;

  void throwIfError() {
    if (error != null) throw error!;
  }
}
