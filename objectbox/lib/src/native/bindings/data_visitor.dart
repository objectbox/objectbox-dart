import 'dart:ffi';

import 'bindings.dart';
import 'helpers.dart';

/// Callback for reading data one-by-one, see [visit].
typedef VisitCallback = bool Function(Pointer<Uint8> data, int size);

/// Currently FFI's Pointer.fromFunction only allows to pass a static Dart
/// callback function. When passing a closure it would throw at runtime:
///     Error: fromFunction expects a static function as parameter.
///     dart:ffi only supports calling static Dart functions from native code.
///     Closures and tear-offs are not supported because they can capture context.
///
/// So given that and
/// - it is required that each query has its own callback,
/// - it is possible that as part of visiting results another query is created
///   and visits its results (e.g. query run in entity constructor or setter) and
/// - Dart code within an isolate is executed synchronously:
///
/// Create a single static callback function [_callbackWrapper] that wraps
/// the actual Dart callback of the query currently visiting results.
/// Keep callbacks on a [_callbackStack] to restore the callback of an outer
/// query once a nested query is finished visiting results.
List<VisitCallback> _callbackStack = [];

bool _callbackWrapper(Pointer<Uint8> dataPtr, int size, Pointer<Void> _) =>
    _callbackStack.last(dataPtr, size);

final Pointer<obx_data_visitor> _callbackWrapperPtr =
    Pointer.fromFunction(_callbackWrapper, false);

/// Visits query results.
///
/// Pass a [callback] for reading data one-by-one:
/// - [data] is the read data buffer.
/// - [size] specifies the length of the read data.
/// - Return true to keep going, false to cancel.
@pragma('vm:prefer-inline')
void visit(Pointer<OBX_query> queryPtr, VisitCallback callback) {
  // Keep callback in case another query is created and visits results
  // within the callback.
  _callbackStack.add(callback);
  final code = C.query_visit(queryPtr, _callbackWrapperPtr, nullptr);
  _callbackStack.removeLast();
  // Clean callback from stack before potentially throwing.
  checkObx(code);
}

/// Can be used with [visit] to get an error out of the callback.
class ObjectVisitorError {
  /// Set this e.g. to an exception that occurred inside the callback.
  Object? error;

  /// Call once visiting is finished. If an exception is set to [error] will
  /// re-throw it.
  void throwIfError() {
    if (error != null) throw error!;
  }
}
