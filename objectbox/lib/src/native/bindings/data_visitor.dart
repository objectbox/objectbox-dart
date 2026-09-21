import 'dart:ffi';

import 'bindings.dart';
import 'helpers.dart';

/// Callback for reading query results one-by-one, see [visit].
typedef VisitCallback = bool Function(Pointer<Uint8> data, int size);

/// Callback for reading query results one-by-one, see [visitWithScore].
typedef VisitWithScoreCallback = bool Function(Pointer<OBX_bytes_score> data);

/// Native signature of [obx_data_visitor].
typedef _DataVisitorNative =
    Bool Function(Pointer<Uint8> data, Size size, Pointer<Void> userData);

/// Native signature of [obx_data_score_visitor].
typedef _DataScoreVisitorNative =
    Bool Function(Pointer<OBX_bytes_score> data, Pointer<Void> userData);

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
///
/// The [callback] may be a closure and may itself create and visit another
/// query (e.g. a query run in an entity constructor or setter): each call wraps
/// it in its own [NativeCallable] that only lives for the duration of the call.
@pragma('vm:prefer-inline')
void visit(Pointer<OBX_query> queryPtr, VisitCallback callback) {
  final callable = NativeCallable<_DataVisitorNative>.isolateLocal(
    (Pointer<Uint8> data, int size, Pointer<Void> _) => callback(data, size),
    exceptionalReturn: false,
  );
  final int code;
  try {
    code = C.query_visit(queryPtr, callable.nativeFunction, nullptr);
  } finally {
    callable.close();
  }
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
///
/// See [visit] for details on the callback.
@pragma('vm:prefer-inline')
void visitWithScore(
  Pointer<OBX_query> queryPtr,
  VisitWithScoreCallback callback,
) {
  final callable = NativeCallable<_DataScoreVisitorNative>.isolateLocal(
    (Pointer<OBX_bytes_score> data, Pointer<Void> _) => callback(data),
    exceptionalReturn: false,
  );
  final int code;
  try {
    code = C.query_visit_with_score(queryPtr, callable.nativeFunction, nullptr);
  } finally {
    callable.close();
  }
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
