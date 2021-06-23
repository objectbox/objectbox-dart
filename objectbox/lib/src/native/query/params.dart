part of query;

/// Adds capabilities to set query parameters
extension QuerySetParam<EntityT> on Query<EntityT> {
  /// Allows overwriting a query condition value.
  QueryParam<DartType> param<DartType>(QueryProperty<EntityT, DartType> prop) =>
      QueryParam._(this, prop);
}

/// QueryParam
class QueryParam<DartType> {
  final Query _query;
  final QueryProperty _prop;

  QueryParam._(this._query, this._prop);
}

/// QueryParam for string properties
extension QueryParamString on QueryParam<String> {
  set value(String value) {
    final cStr = value.toNativeUtf8();
    try {
      checkObx(C.query_param_string(
          _query._ptr, _query.entityId, _prop._model.id.id, cStr.cast()));
    } finally {
      malloc.free(cStr);
    }
  }

  set values(List<String> values) => withNativeStrings(
      values,
      (Pointer<Pointer<Int8>> ptr, int size) => checkObx(C.query_param_strings(
          _query._ptr, _query.entityId, _prop._model.id.id, ptr, size)));
}

/// QueryParam for byte vector properties
extension QueryParamBytes on QueryParam<List<int>> {
  set value(List<int> value) => withNativeBytes(
      Uint8List.fromList(value),
      (Pointer<Uint8> ptr, int size) => checkObx(C.query_param_bytes(
          _query._ptr, _query.entityId, _prop._model.id.id, ptr, size)));
}

/// QueryParam for int properties
extension QueryParamInt on QueryParam<int> {
  set value(int value) => checkObx(C.query_param_int(
      _query._ptr, _query.entityId, _prop._model.id.id, value));

  set values(List<int> values) {
    final is64bit = _prop._model.type == OBXPropertyType.Long;
    final ptr =
        is64bit ? malloc<Int64>(values.length) : malloc<Int32>(values.length);
    try {
      for (var i = 0; i < values.length; i++) {
        if (is64bit) {
          (ptr as Pointer<Int64>)[i] = values[i];
        } else {
          (ptr as Pointer<Int32>)[i] = values[i];
        }
      }
      checkObx(is64bit
          ? C.query_param_int64s(_query._ptr, _query.entityId,
              _prop._model.id.id, ptr as Pointer<Int64>, values.length)
          : C.query_param_int32s(_query._ptr, _query.entityId,
              _prop._model.id.id, ptr as Pointer<Int32>, values.length));
    } finally {
      malloc.free(ptr);
    }
  }

  /// set values for condition consisting of two values
  void twoValues(int a, int b) => checkObx(C.query_param_2ints(
      _query._ptr, _query.entityId, _prop._model.id.id, a, b));
}

/// QueryParam for double properties
extension QueryParamDouble on QueryParam<double> {
  set value(double value) => checkObx(C.query_param_double(
      _query._ptr, _query.entityId, _prop._model.id.id, value));

  /// set values for condition consisting of two values
  void twoValues(double a, double b) => checkObx(C.query_param_2doubles(
      _query._ptr, _query.entityId, _prop._model.id.id, a, b));
}

/// QueryParam for boolean properties
extension QueryParamBool on QueryParam<bool> {
  set value(bool value) => checkObx(C.query_param_int(
      _query._ptr, _query.entityId, _prop._model.id.id, value ? 1 : 0));
}
