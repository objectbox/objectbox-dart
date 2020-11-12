part of query;

abstract class PropertyQuery<T> {
  Pointer<OBX_query_prop> _cProp;
  int _type;
  bool _distinct;

  PropertyQuery(Pointer<OBX_query> cQuery, int propertyId, int obxType) {
    _type = obxType;
    _cProp = checkObxPtr(
        bindings.obx_query_prop(cQuery, propertyId), 'property query');
  }

  /// Returns values of this property matching the query.
  ///
  /// Results are in no particular order. Excludes null values.
  /// Set [replaceNullWith] to return null values as that value.
  List<T> find({T replaceNullWith});

  void close() {
    checkObx(bindings.obx_query_prop_close(_cProp));
  }

  bool get distinct => _distinct;

  /// Set to only return distinct values.
  ///
  /// E.g. 1,2,3 instead of 1,1,2,3,3,3. Strings default to case-insensitive comparision.
  set distinct(bool d) {
    _distinct = d;
    checkObx(bindings.obx_query_prop_distinct(_cProp, d));
  }

  /// Returns the count of non-null values.
  int count() {
    final ptr = allocate<Uint64>(count: 1);
    try {
      checkObx(bindings.obx_query_prop_count(_cProp, ptr));
      return ptr.value;
    } finally {
      free(ptr);
    }
  }

  List<R> _find<R, StructT extends NativeType, ValT extends NativeType>(
      Pointer<StructT> Function(Pointer<OBX_query_prop>, Pointer<ValT>) findFn,
      Pointer<ValT> cDefault,
      List<R> Function(Pointer<StructT>) listReadFn,
      void Function(Pointer<StructT>) listFreeFn) {
    Pointer<StructT> cItems;
    try {
      cItems = checkObxPtr(findFn(_cProp, cDefault), 'Property query failed');
      return listReadFn(cItems);
    } finally {
      if (cDefault != nullptr) free(cDefault);
      if (cItems != nullptr) listFreeFn(cItems);
    }
  }

  Pointer<ValT> _cDefault<ValT extends NativeType>(dynamic valueIfNull) =>
      valueIfNull == null ? nullptr : allocate<ValT>();
}

/// shared implementation, hence mixin
mixin _CommonNumeric<T> on PropertyQuery<T> {
  double average() {
    final ptr = allocate<Double>();
    try {
      checkObx(bindings.obx_query_prop_avg(_cProp, ptr, nullptr));
      return ptr.value;
    } finally {
      free(ptr);
    }
  }
}

class IntegerPropertyQuery extends PropertyQuery<int> with _CommonNumeric {
  IntegerPropertyQuery(Pointer<OBX_query> query, int propertyId, int obxType)
      : super(query, propertyId, obxType);

  int _op(
      int Function(Pointer<OBX_query_prop>, Pointer<Int64>, Pointer<Int64>)
          fn) {
    final ptr = allocate<Int64>();
    try {
      checkObx(fn(_cProp, ptr, nullptr));
      return ptr.value;
    } finally {
      free(ptr);
    }
  }

  int min() {
    return _op(bindings.obx_query_prop_min_int);
  }

  int max() {
    return _op(bindings.obx_query_prop_max_int);
  }

  int sum() {
    return _op(bindings.obx_query_prop_sum_int);
  }

  @override
  List<int> find({int replaceNullWith}) {
    switch (_type) {
      case OBXPropertyType.Bool:
      case OBXPropertyType.Byte:
      case OBXPropertyType.Char: // Int8
        final cDefault = _cDefault<Int8>(replaceNullWith);
        if (replaceNullWith != null) cDefault.value = replaceNullWith;
        return _find(
            bindings.obx_query_prop_find_int8s,
            cDefault,
            (Pointer<OBX_int8_array> cItems) =>
                cItems.ref.items.asTypedList(cItems.ref.count).toList(),
            bindings.obx_int8_array_free);
      case OBXPropertyType.Short: // Int16
        final cDefault = _cDefault<Int16>(replaceNullWith);
        if (replaceNullWith != null) cDefault.value = replaceNullWith;
        return _find(
            bindings.obx_query_prop_find_int16s,
            cDefault,
            (Pointer<OBX_int16_array> cItems) =>
                cItems.ref.items.asTypedList(cItems.ref.count).toList(),
            bindings.obx_int16_array_free);
      case OBXPropertyType.Int: // Int32
        final cDefault = _cDefault<Int32>(replaceNullWith);
        if (replaceNullWith != null) cDefault.value = replaceNullWith;
        return _find(
            bindings.obx_query_prop_find_int32s,
            cDefault,
            (Pointer<OBX_int32_array> cItems) =>
                cItems.ref.items.asTypedList(cItems.ref.count).toList(),
            bindings.obx_int32_array_free);
      case OBXPropertyType.Long: // Int64
        final cDefault = _cDefault<Int64>(replaceNullWith);
        if (replaceNullWith != null) cDefault.value = replaceNullWith;
        return _find(
            bindings.obx_query_prop_find_int64s,
            cDefault,
            (Pointer<OBX_int64_array> cItems) =>
                cItems.ref.items.asTypedList(cItems.ref.count).toList(),
            bindings.obx_int64_array_free);
      default:
        throw Exception(
            'Property query: unsupported type (OBXPropertyType: ${_type})');
    }
  }
}

class DoublePropertyQuery extends PropertyQuery<double> with _CommonNumeric {
  DoublePropertyQuery(Pointer<OBX_query> query, int propertyId, int obxType)
      : super(query, propertyId, obxType);

  double _op(
      int Function(Pointer<OBX_query_prop>, Pointer<Double>, Pointer<Int64>)
          fn) {
    final ptr = allocate<Double>();
    try {
      checkObx(fn(_cProp, ptr, nullptr));
      return ptr.value;
    } finally {
      free(ptr);
    }
  }

  double min() {
    return _op(bindings.obx_query_prop_min);
  }

  double max() {
    return _op(bindings.obx_query_prop_max);
  }

  double sum() {
    return _op(bindings.obx_query_prop_sum);
  }

  @override
  List<double> find({double replaceNullWith}) {
    switch (_type) {
      case OBXPropertyType.Float:
        final cDefault = _cDefault<Float>(replaceNullWith);
        if (replaceNullWith != null) cDefault.value = replaceNullWith;
        return _find(
            bindings.obx_query_prop_find_floats,
            cDefault,
            (Pointer<OBX_float_array> cItems) =>
                cItems.ref.items.asTypedList(cItems.ref.count).toList(),
            bindings.obx_float_array_free);
      case OBXPropertyType.Double:
        final cDefault = _cDefault<Double>(replaceNullWith);
        if (replaceNullWith != null) cDefault.value = replaceNullWith;
        return _find(
            bindings.obx_query_prop_find_doubles,
            cDefault,
            (Pointer<OBX_double_array> cItems) =>
                cItems.ref.items.asTypedList(cItems.ref.count).toList(),
            bindings.obx_double_array_free);
      default:
        throw Exception(
            'Property query: unsupported type (OBXPropertyType: ${_type})');
    }
  }
}

class StringPropertyQuery extends PropertyQuery<String> {
  bool _caseSensitive = false;

  StringPropertyQuery(Pointer<OBX_query> query, int propertyId, int obxType)
      : super(query, propertyId, obxType);

  /// Set to return case sensitive distinct values.
  ///
  /// E.g. returning "foo","Foo","FOO" instead of just "foo".
  set caseSensitive(bool caseSensitive) {
    _caseSensitive = caseSensitive;
    checkObx(bindings.obx_query_prop_distinct_case(
        _cProp, _distinct, _caseSensitive));
  }

  bool get caseSensitive => _caseSensitive;

  @override
  set distinct(bool d) {
    _distinct = d;
    checkObx(bindings.obx_query_prop_distinct_case(_cProp, d, _caseSensitive));
  }

  @override
  List<String> find({String replaceNullWith}) {
    final cDefault = replaceNullWith == null
        ? nullptr
        : Utf8.toUtf8(replaceNullWith).cast<Int8>();

    return _find(
        bindings.obx_query_prop_find_strings,
        cDefault,
        (Pointer<OBX_string_array> cItems) =>
            OBX_string_array_wrapper(cItems).items(),
        bindings.obx_string_array_free);
  }
}
