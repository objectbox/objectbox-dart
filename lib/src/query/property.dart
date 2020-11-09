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
    checkObx(bindings.obx_query_prop_distinct(_cProp, d ? 1 : 0));
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

  Pointer<TStruct>
      _curryWithDefault<TStruct extends Struct, N extends NativeType>(
          obx_query_prop_find_native_t<Pointer<TStruct>, N> findFn,
          Pointer<N> cDefault,
          String errorMessage) {
    try {
      return checkObxPtr(findFn(_cProp, cDefault), errorMessage);
    } finally {
      if (cDefault.address != 0) {
        free(cDefault);
      }
    }
  }
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

  int _op(obx_query_prop_op_t<int, Int64> fn) {
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

  List<int> _unpack8(Pointer<OBX_int8_array> ptr) {
    try {
      return ptr.ref.items();
    } finally {
      bindings.obx_int8_array_free(ptr);
    }
  }

  List<int> _unpack16(Pointer<OBX_int16_array> ptr) {
    try {
      return ptr.ref.items();
    } finally {
      bindings.obx_int16_array_free(ptr);
    }
  }

  List<int> _unpack32(Pointer<OBX_int32_array> ptr) {
    try {
      return ptr.ref.items();
    } finally {
      bindings.obx_int32_array_free(ptr);
    }
  }

  List<int> _unpack64(Pointer<OBX_int64_array> ptr) {
    try {
      return ptr.ref.items();
    } finally {
      bindings.obx_int64_array_free(ptr);
    }
  }

  @override
  List<int> find({int replaceNullWith}) {
    final ptr = replaceNullWith != null
        ? (allocate<Int64>()..value = replaceNullWith)
        : Pointer<Int64>.fromAddress(0);
    switch (_type) {
      case OBXPropertyType.Bool:
      case OBXPropertyType.Byte:
      case OBXPropertyType.Char: // Int8
        return _unpack8(_curryWithDefault<OBX_int8_array, Int8>(
            bindings.obx_query_prop_find_int8s, ptr.cast<Int8>(), 'find int8'));
      case OBXPropertyType.Short: // Int16
        return _unpack16(_curryWithDefault<OBX_int16_array, Int16>(
            bindings.obx_query_prop_find_int16s,
            ptr.cast<Int16>(),
            'find int16'));
      case OBXPropertyType.Int: // Int32
        return _unpack32(_curryWithDefault<OBX_int32_array, Int32>(
            bindings.obx_query_prop_find_int32s,
            ptr.cast<Int32>(),
            'find int32'));
      case OBXPropertyType.Long: // Int64
        return _unpack64(_curryWithDefault<OBX_int64_array, Int64>(
            bindings.obx_query_prop_find_int64s,
            ptr.cast<Int64>(),
            'find int64'));
      default:
        throw Exception(
            'Property query: unsupported type (OBXPropertyType: ${_type})');
    }
  }
}

class DoublePropertyQuery extends PropertyQuery<double> with _CommonNumeric {
  DoublePropertyQuery(Pointer<OBX_query> query, int propertyId, int obxType)
      : super(query, propertyId, obxType);

  double _op(obx_query_prop_op_t<int, Double> fn) {
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

  List<double> _unpack32(Pointer<OBX_float_array> ptr) {
    try {
      return ptr.ref.items();
    } finally {
      bindings.obx_float_array_free(ptr);
    }
  }

  List<double> _unpack64(Pointer<OBX_double_array> ptr) {
    try {
      return ptr.ref.items();
    } finally {
      bindings.obx_double_array_free(ptr);
    }
  }

  @override
  List<double> find({double replaceNullWith}) {
    switch (_type) {
      case OBXPropertyType.Float:
        final valueIfNull = replaceNullWith != null
            ? (allocate<Float>()..value = replaceNullWith)
            : Pointer<Float>.fromAddress(0);
        return _unpack32(_curryWithDefault<OBX_float_array, Float>(
            bindings.obx_query_prop_find_floats, valueIfNull, 'find float32'));
      case OBXPropertyType.Double:
        final valueIfNull = replaceNullWith != null
            ? (allocate<Double>()..value = replaceNullWith)
            : Pointer<Double>.fromAddress(0);
        return _unpack64(_curryWithDefault<OBX_double_array, Double>(
            bindings.obx_query_prop_find_doubles, valueIfNull, 'find float64'));
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
        _cProp, _distinct ? 1 : 0, _caseSensitive ? 1 : 0));
  }

  bool get caseSensitive => _caseSensitive;

  @override
  set distinct(bool d) {
    _distinct = d;
    checkObx(bindings.obx_query_prop_distinct_case(
        _cProp, d ? 1 : 0, _caseSensitive ? 1 : 0));
  }

  @override
  List<String> find({String replaceNullWith}) {
    final ptr = replaceNullWith != null
        ? Utf8.toUtf8(replaceNullWith).cast<Int8>()
        : Pointer<Int8>.fromAddress(0);
    final stringArray = OBX_string_array_wrapper(
        _curryWithDefault<OBX_string_array, Int8>(
            bindings.obx_query_prop_find_strings, ptr, 'find utf8'));
    return stringArray.items();
  }
}
