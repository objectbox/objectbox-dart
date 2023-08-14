import 'dart:ffi';

import 'bindings.dart';
import 'helpers.dart';

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

bool _forwarder(Pointer<Uint8> dataPtr, int size, Pointer<Void> _) =>
    _callback(dataPtr, size);

final Pointer<obx_data_visitor> _nativeVisitor =
    Pointer.fromFunction(_forwarder, false);

/// Visits query results.
///
/// Pass a [callback] for reading data one-by-one:
/// - [data] is the read data buffer.
/// - [size] specifies the length of the read data.
/// - Return true to keep going, false to cancel.
@pragma('vm:prefer-inline')
void visit(Pointer<OBX_query> queryPtr,
    bool Function(Pointer<Uint8> data, int size) callback) {
  _callback = callback;
  checkObx(C.query_visit(queryPtr, _nativeVisitor, nullptr));
}

/// Can be used with [visit] to get an error out of the callback.
class ObjectCollectorError {
  /// Set this e.g. to an exception that occurred inside the callback.
  Object? error;

  /// Call once visiting is finished. If an exception is set to [error] will
  /// re-throw it.
  void throwIfError() {
    if (error != null) throw error!;
  }
}
