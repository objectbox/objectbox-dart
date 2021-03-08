part of query;

/// Property query base.
abstract class PropertyQuery<T> {
  final Pointer<OBX_query_prop> _cProp;
  final int _type;
  bool _distinct = false;

  PropertyQuery._(Pointer<OBX_query> cQuery, int propertyId, this._type)
      : _cProp =
            checkObxPtr(C.query_prop(cQuery, propertyId), 'property query');

  /// Returns values of this property matching the query.
  ///
  /// Results are in no particular order. Excludes null values.
  /// Set [replaceNullWith] to return null values as that value.
  List<T> find({T /*?*/ replaceNullWith});

  /// Close the property query, freeing its resources
  void close() {
    checkObx(C.query_prop_close(_cProp));
  }

  /// Get the status of "distinct-values" configuration.
  bool get distinct => _distinct;

  /// Set to only return distinct values.
  ///
  /// E.g. [1,2,3] instead of [1,1,2,3,3,3].
  /// Strings default to case-insensitive comparison.
  set distinct(bool d) {
    _distinct = d;
    checkObx(C.query_prop_distinct(_cProp, d));
  }

  /// Returns the count of non-null values.
  int count() {
    final ptr = malloc<Uint64>();
    try {
      checkObx(C.query_prop_count(_cProp, ptr));
      return ptr.value;
    } finally {
      malloc.free(ptr);
    }
  }

  List<R> _find<R, StructT extends NativeType, ValT extends NativeType>(
      Pointer<StructT> Function(Pointer<OBX_query_prop>, Pointer<ValT>) findFn,
      Pointer<ValT> cDefault,
      List<R> Function(Pointer<StructT>) listReadFn,
      void Function(Pointer<StructT>) listFreeFn) {
    Pointer<StructT> cItems = nullptr;
    try {
      cItems = checkObxPtr(findFn(_cProp, cDefault), 'Property query failed');
      return listReadFn(cItems);
    } finally {
      if (cDefault != nullptr) malloc.free(cDefault);
      if (cItems != nullptr) listFreeFn(cItems);
    }
  }
}

/// shared implementation, hence mixin
mixin _CommonNumeric<T> on PropertyQuery<T> {
  /// Average value of the property over all objects matching the query.
  double average() {
    final ptr = malloc<Double>();
    try {
      checkObx(C.query_prop_avg(_cProp, ptr, nullptr));
      return ptr.value;
    } finally {
      malloc.free(ptr);
    }
  }
}

/// "Property query" for an integer field. Created by [Query.property()].
class IntegerPropertyQuery extends PropertyQuery<int> with _CommonNumeric {
  IntegerPropertyQuery._(Pointer<OBX_query> query, int propertyId, int obxType)
      : super._(query, propertyId, obxType);

  int _op(
      int Function(Pointer<OBX_query_prop>, Pointer<Int64>, Pointer<Int64>)
          fn) {
    final ptr = malloc<Int64>();
    try {
      checkObx(fn(_cProp, ptr, nullptr));
      return ptr.value;
    } finally {
      malloc.free(ptr);
    }
  }

  /// Minimum value of the property over all objects matching the query.
  int min() => _op(C.query_prop_min_int);

  /// Maximum value of the property over all objects matching the query.
  int max() => _op(C.query_prop_max_int);

  /// Sum of all property values over objects matching the query.
  int sum() => _op(C.query_prop_sum_int);

  @override
  List<int> find({int /*?*/ replaceNullWith}) {
    switch (_type) {
      case OBXPropertyType.Bool:
      case OBXPropertyType.Byte:
      case OBXPropertyType.Char: // Int8
        final cDefault = replaceNullWith == null ? nullptr : malloc<Int8>();
        if (replaceNullWith != null) cDefault.value = replaceNullWith;
        return _find(
            C.query_prop_find_int8s,
            cDefault,
            (Pointer<OBX_int8_array> cItems) =>
                cItems.ref.items.asTypedList(cItems.ref.count).toList(),
            C.int8_array_free);
      case OBXPropertyType.Short: // Int16
        final cDefault = replaceNullWith == null ? nullptr : malloc<Int16>();
        if (replaceNullWith != null) cDefault.value = replaceNullWith;
        return _find(
            C.query_prop_find_int16s,
            cDefault,
            (Pointer<OBX_int16_array> cItems) =>
                cItems.ref.items.asTypedList(cItems.ref.count).toList(),
            C.int16_array_free);
      case OBXPropertyType.Int: // Int32
        final cDefault = replaceNullWith == null ? nullptr : malloc<Int32>();
        if (replaceNullWith != null) cDefault.value = replaceNullWith;
        return _find(
            C.query_prop_find_int32s,
            cDefault,
            (Pointer<OBX_int32_array> cItems) =>
                cItems.ref.items.asTypedList(cItems.ref.count).toList(),
            C.int32_array_free);
      case OBXPropertyType.Long: // Int64
        final cDefault = replaceNullWith == null ? nullptr : malloc<Int64>();
        if (replaceNullWith != null) cDefault.value = replaceNullWith;
        return _find(
            C.query_prop_find_int64s,
            cDefault,
            (Pointer<OBX_int64_array> cItems) =>
                cItems.ref.items.asTypedList(cItems.ref.count).toList(),
            C.int64_array_free);
      default:
        throw Exception(
            'Property query: unsupported type (OBXPropertyType: $_type)');
    }
  }
}

/// "Property query" for a double field. Created by [Query.property()].
class DoublePropertyQuery extends PropertyQuery<double> with _CommonNumeric {
  DoublePropertyQuery._(Pointer<OBX_query> query, int propertyId, int obxType)
      : super._(query, propertyId, obxType);

  double _op(
      int Function(Pointer<OBX_query_prop>, Pointer<Double>, Pointer<Int64>)
          fn) {
    final ptr = malloc<Double>();
    try {
      checkObx(fn(_cProp, ptr, nullptr));
      return ptr.value;
    } finally {
      malloc.free(ptr);
    }
  }

  /// Minimum value of the property over all objects matching the query.
  double min() => _op(C.query_prop_min);

  /// Maximum value of the property over all objects matching the query.
  double max() => _op(C.query_prop_max);

  /// Sum of all property values over objects matching the query.
  double sum() => _op(C.query_prop_sum);

  @override
  List<double> find({double /*?*/ replaceNullWith}) {
    switch (_type) {
      case OBXPropertyType.Float:
        final cDefault = replaceNullWith == null ? nullptr : malloc<Float>();
        if (replaceNullWith != null) cDefault.value = replaceNullWith;
        return _find(
            C.query_prop_find_floats,
            cDefault,
            (Pointer<OBX_float_array> cItems) =>
                cItems.ref.items.asTypedList(cItems.ref.count).toList(),
            C.float_array_free);
      case OBXPropertyType.Double:
        final cDefault = replaceNullWith == null ? nullptr : malloc<Double>();
        if (replaceNullWith != null) cDefault.value = replaceNullWith;
        return _find(
            C.query_prop_find_doubles,
            cDefault,
            (Pointer<OBX_double_array> cItems) =>
                cItems.ref.items.asTypedList(cItems.ref.count).toList(),
            C.double_array_free);
      default:
        throw Exception(
            'Property query: unsupported type (OBXPropertyType: $_type)');
    }
  }
}

/// "Property query" for a string field. Created by [Query.property()].
class StringPropertyQuery extends PropertyQuery<String> {
  bool _caseSensitive = false;

  StringPropertyQuery._(Pointer<OBX_query> query, int propertyId, int obxType)
      : super._(query, propertyId, obxType);

  /// Set to return case sensitive distinct values.
  ///
  /// E.g. returning "foo","Foo","FOO" instead of just "foo".
  set caseSensitive(bool caseSensitive) {
    _caseSensitive = caseSensitive;
    checkObx(C.query_prop_distinct_case(_cProp, _distinct, _caseSensitive));
  }

  /// Get status of the case-sensitive configuration.
  bool get caseSensitive => _caseSensitive;

  @override
  set distinct(bool d) {
    _distinct = d;
    checkObx(C.query_prop_distinct_case(_cProp, d, _caseSensitive));
  }

  @override
  List<String> find({String /*?*/ replaceNullWith}) {
    final cDefault =
        replaceNullWith == null ? nullptr : replaceNullWith.toNativeUtf8();

    return _find(
        C.query_prop_find_strings,
        cDefault.cast<Int8>(),
        (Pointer<OBX_string_array> cItems) => cItems.toDartStrings(),
        C.string_array_free);
  }
}
