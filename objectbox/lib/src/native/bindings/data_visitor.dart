import 'dart:ffi';

import 'bindings.dart';
import 'helpers.dart';

/// Callback for reading query results one-by-one, see [visit].
typedef VisitCallback = bool Function(Pointer<Uint8> data, int size);

/// Callback for reading query results one-by-one, see [visitWithScore].
typedef VisitWithScoreCallback = bool Function(Pointer<OBX_bytes_score> data);

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
/// Create a single static callback function [_visitCallbackWrapper] that wraps
/// the actual Dart callback of the query currently visiting results.
/// Keep callbacks on a [_visitCallbackStack] to restore the callback of an outer
/// query once a nested query is finished visiting results.
List<VisitCallback> _visitCallbackStack = [];

/// Like [_visitCallbackStack], but for [VisitWithScoreCallback].
List<VisitWithScoreCallback> _visitWithScoreCallbackStack = [];

bool _visitCallbackWrapper(Pointer<Uint8> dataPtr, int size, Pointer<Void> _) =>
    _visitCallbackStack.last(dataPtr, size);

bool _visitWithScoreCallbackWrapper(
        Pointer<OBX_bytes_score> dataPtr, Pointer<Void> _) =>
    _visitWithScoreCallbackStack.last(dataPtr);

final Pointer<obx_data_visitor> _visitCallbackWrapperPtr =
    Pointer.fromFunction(_visitCallbackWrapper, false);

final Pointer<obx_data_score_visitor> _visitWithScoreCallbackWrapperPtr =
    Pointer.fromFunction(_visitWithScoreCallbackWrapper, false);

/// Visits query results to read results one by one (in chunks).
///
/// This is useful to support large objects in 32-bit mode.
///
/// Pass a [callback] for reading data one by one:
/// - [data] is the read data buffer.
/// - [size] specifies the length of the read data.
/// - Return true to keep going, false to cancel.
///
/// Use [ObjectVisitorError] to get an error out of the callback.
@pragma('vm:prefer-inline')
void visit(Pointer<OBX_query> queryPtr, VisitCallback callback) {
  // Keep callback in case another query is created and visits results
  // within the callback.
  _visitCallbackStack.add(callback);
  final code = C.query_visit(queryPtr, _visitCallbackWrapperPtr, nullptr);
  _visitCallbackStack.removeLast();
  // Clean callback from stack before potentially throwing.
  checkObx(code);
}

/// Visits query with score results to read results one by one (in chunks).
///
/// This is useful to support large objects in 32-bit mode.
///
/// Pass a [callback] for reading data one by one.
/// - [data] is a [OBX_bytes_score] that iself contains data of the object and
/// the length of the data.
/// - Return true to keep going, false to cancel.
///
/// Use [ObjectVisitorError] to get an error out of the callback.
@pragma('vm:prefer-inline')
void visitWithScore(
    Pointer<OBX_query> queryPtr, VisitWithScoreCallback callback) {
  // Keep callback in case another query is created and visits results
  // within the callback.
  _visitWithScoreCallbackStack.add(callback);
  final code = C.query_visit_with_score(
      queryPtr, _visitWithScoreCallbackWrapperPtr, nullptr);
  _visitWithScoreCallbackStack.removeLast();
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
