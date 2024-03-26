part of 'query.dart';

/// Adds capabilities to set query parameters
extension QuerySetParam on Query {
  /// Allows overwriting a query condition value, making queries reusable.
  ///
  /// Example for a property that's used only once in a query (no alias needed):
  /// ```dart
  /// class App {
  ///   // a reusable query
  ///   late final query = box.query(Person_.name.startsWith('')).build();
  /// }
  ///
  /// // later in app code, reuse the query as many times as you want
  /// app.query.param(Person_.name).value = 'A';
  /// final peopleStartingWithA = app.query.find();
  /// app.query.param(Person_.name).value = 'B';
  /// final peopleStartingWithB = app.query.find();
  /// ```
  ///
  /// Example for a property used multiple times (requires an [alias] that is
  /// unique for the whole query):
  /// ```dart
  /// class App {
  ///   // a reusable query
  ///   late final query = box.query(
  ///     Person_.name.startsWith('', alias: 'start') &
  ///     Person_.name.endsWith('', alias: 'end')
  ///   ).build();
  /// }
  ///
  /// // later in app code, reuse the query as many times as you want
  /// app.query
  ///   ..param(Person_.name, alias: 'start').value = 'A'
  ///   ..param(Person_.name, alias: 'end').value = 'b';
  /// final people = app.query.find();
  /// ```
  QueryParam<DartType> param<EntityT, DartType>(
          QueryProperty<EntityT, DartType> prop,
          {String? alias}) =>
      QueryParam._(
          this,
          InternalStoreAccess.entityDef<EntityT>(_store).model.id.id,
          prop,
          alias);
}

/// QueryParam
class QueryParam<DartType> {
  final Query _query;
  final int _entityId;
  final QueryProperty _prop;
  final String? _alias;

  QueryParam._(this._query, this._entityId, this._prop, this._alias);
}

/// QueryParam for string properties
extension QueryParamString on QueryParam<String> {
  set value(String value) {
    if (_alias == null) {
      withNativeString(
          value,
          (Pointer<Char> cStr) => checkObx(C.query_param_string(
              _query._ptr, _entityId, _prop._model.id.id, cStr)));
    } else {
      withNativeStrings(
          [_alias!, value],
          (Pointer<Pointer<Char>> ptr, int size) => checkObx(
              C.query_param_alias_string(_query._ptr, ptr[0], ptr[1])));
    }
  }

  set values(List<String> values) => withNativeStrings(
      values,
      (Pointer<Pointer<Char>> ptr, int size) => checkObx((_alias == null)
          ? C.query_param_strings(
              _query._ptr, _entityId, _prop._model.id.id, ptr, size)
          : withNativeString(
              _alias!,
              (Pointer<Char> cAlias) => C.query_param_alias_strings(
                  _query._ptr, cAlias, ptr, size))));
}

/// QueryParam for byte vector properties
extension QueryParamBytes on QueryParam<List<int>> {
  set value(List<int> value) => withNativeBytes(
      Uint8List.fromList(value),
      (Pointer<Uint8> ptr, int size) => checkObx((_alias == null)
          ? C.query_param_bytes(
              _query._ptr, _entityId, _prop._model.id.id, ptr, size)
          : withNativeString(
              _alias!,
              (Pointer<Char> cAlias) =>
                  C.query_param_alias_bytes(_query._ptr, cAlias, ptr, size))));
}

/// QueryParam for int properties
extension QueryParamInt on QueryParam<int> {
  set value(int value) => checkObx((_alias == null)
      ? C.query_param_int(_query._ptr, _entityId, _prop._model.id.id, value)
      : withNativeString(
          _alias!,
          (Pointer<Char> cAlias) =>
              C.query_param_alias_int(_query._ptr, cAlias, value)));

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
      if (_alias == null) {
        checkObx(is64bit
            ? C.query_param_int64s(_query._ptr, _entityId, _prop._model.id.id,
                ptr as Pointer<Int64>, values.length)
            : C.query_param_int32s(_query._ptr, _entityId, _prop._model.id.id,
                ptr as Pointer<Int32>, values.length));
      } else {
        withNativeString(
            _alias!,
            (Pointer<Char> cAlias) => checkObx(is64bit
                ? C.query_param_alias_int64s(
                    _query._ptr, cAlias, ptr as Pointer<Int64>, values.length)
                : C.query_param_alias_int32s(_query._ptr, cAlias,
                    ptr as Pointer<Int32>, values.length)));
      }
    } finally {
      malloc.free(ptr);
    }
  }

  /// set values for condition consisting of two values
  void twoValues(int a, int b) => checkObx((_alias == null)
      ? C.query_param_2ints(_query._ptr, _entityId, _prop._model.id.id, a, b)
      : withNativeString(
          _alias!,
          (Pointer<Char> cAlias) =>
              C.query_param_alias_2ints(_query._ptr, cAlias, a, b)));
}

/// QueryParam for double properties
extension QueryParamDouble on QueryParam<double> {
  set value(double value) => checkObx((_alias == null)
      ? C.query_param_double(_query._ptr, _entityId, _prop._model.id.id, value)
      : withNativeString(
          _alias!,
          (Pointer<Char> cAlias) =>
              C.query_param_alias_double(_query._ptr, cAlias, value)));

  /// set values for condition consisting of two values
  void twoValues(double a, double b) => checkObx((_alias == null)
      ? C.query_param_2doubles(_query._ptr, _entityId, _prop._model.id.id, a, b)
      : withNativeString(
          _alias!,
          (Pointer<Char> cAlias) =>
              C.query_param_alias_2doubles(_query._ptr, cAlias, a, b)));

  /// Set values for the nearest neighbor condition.
  void nearestNeighborsF32(List<double> queryVector, int maxResultCount) {
    withNativeFloats(queryVector, (floatsPtr, size) {
      if (_alias == null) {
        checkObx(C.query_param_vector_float32(
            _query._ptr, _entityId, _prop._model.id.id, floatsPtr, size));
        checkObx(C.query_param_int(
            _query._ptr, _entityId, _prop._model.id.id, maxResultCount));
      } else {
        withNativeString(_alias!, (aliasPtr) {
          checkObx(C.query_param_alias_vector_float32(
              _query._ptr, aliasPtr, floatsPtr, size));
          checkObx(
              C.query_param_alias_int(_query._ptr, aliasPtr, maxResultCount));
        });
      }
    });
  }
}

/// QueryParam for boolean properties
extension QueryParamBool on QueryParam<bool> {
  set value(bool value) => checkObx((_alias == null)
      ? C.query_param_int(
          _query._ptr, _entityId, _prop._model.id.id, value ? 1 : 0)
      : withNativeString(
          _alias!,
          (Pointer<Char> cAlias) =>
              C.query_param_alias_int(_query._ptr, cAlias, value ? 1 : 0)));
}
