part of query;

class PropertyQuery {
  Pointer<Void> _cProp;
  int _type;
  bool _distinct;

  PropertyQuery(Pointer<Void> cQuery, int propertyId, int obxType) {
    this._type = obxType;
    _cProp = checkObxPtr(bindings.obx_query_prop(cQuery, propertyId), "property query");
  }

  void close() {
    checkObx(bindings.obx_query_prop_close(_cProp));
  }

  get distinct => _distinct;

  set distinct (bool d) {
    _distinct = d;
    checkObx(bindings.obx_query_prop_distinct(_cProp, d ? 1 : 0));
  }

  int count() {
    final ptr = allocate<Uint64>(count: 1);
    try {
      checkObx(bindings.obx_query_prop_count(_cProp, ptr));
      return ptr.value;
    }finally {
      free(ptr);
    }
  }

  Pointer<TStruct> _curryWithDefault<TStruct extends Struct, N extends NativeType>
      (obx_query_prop_find_native_t<Pointer<TStruct>, N> findFn, Pointer<N> cDefault, String errorMessage) {
    try {
      return checkObxPtr(findFn(_cProp, cDefault), errorMessage);
    }finally {
      if (cDefault.address != 0) {
        free(cDefault);
      }
    }
  }
}

/// shared implementation, hence mixin
mixin _CommonNumeric on PropertyQuery {

  double average() {
    final ptr = allocate<Double>();
    try {
      checkObx(bindings.obx_query_prop_avg(_cProp, ptr));
      return ptr.value;
    } finally {
      free(ptr);
    }
  }

}

class IntegerPropertyQuery extends PropertyQuery with _CommonNumeric {

  IntegerPropertyQuery (Pointer<Void> query, int propertyId, int obxType): super(query, propertyId, obxType);

  int _op(obx_query_prop_op_t<int, Int64> fn) {
    final ptr = allocate<Int64>();
    try {
      checkObx(fn(_cProp, ptr));
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
    }finally {
      bindings.obx_int64_array_free(ptr);
    }
  }

  List<int> find({int replaceNullWith}) {
    final ptr = replaceNullWith != null ? (allocate<Int64>()..value = replaceNullWith) : Pointer<Int64>.fromAddress(0);
    switch(_type) {
      case OBXPropertyType.Bool:
      case OBXPropertyType.Byte:
      case OBXPropertyType.Char:  // Int8
        return _unpack8(_curryWithDefault<OBX_int8_array, Int8>
          (bindings.obx_query_prop_int8_find, ptr.cast<Int8>(), "find int8"));
      case OBXPropertyType.Short: // Int16
        return _unpack16(_curryWithDefault<OBX_int16_array, Int16>
          (bindings.obx_query_prop_int16_find, ptr.cast<Int16>(), "find int16"));
      case OBXPropertyType.Int:   // Int32
        return _unpack32(_curryWithDefault<OBX_int32_array, Int32>
          (bindings.obx_query_prop_int32_find, ptr.cast<Int32>(), "find int32"));
      case OBXPropertyType.Long:  // Int64
        return _unpack64(_curryWithDefault<OBX_int64_array, Int64>
          (bindings.obx_query_prop_int64_find, ptr.cast<Int64>(), "find int64"));
      default:
        throw Exception('Property query: unsupported type (OBXPropertyType: ${_type})');
    }
  }
}

class DoublePropertyQuery extends PropertyQuery with _CommonNumeric {

  DoublePropertyQuery (Pointer<Void> query, int propertyId, int obxType): super(query, propertyId, obxType);

  double _op(obx_query_prop_op_t<int, Double> fn) {
    final ptr = allocate<Double>();
    try {
      checkObx(fn(_cProp, ptr));
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
    }finally {
      bindings.obx_float_array_free(ptr);
    }
  }

  List<double> _unpack64(Pointer<OBX_double_array> ptr) {
    try {
      return ptr.ref.items();
    }finally {
      bindings.obx_double_array_free(ptr);
    }
  }

  List<double> find({double replaceNullWith}) {
    final ptr = replaceNullWith != null ? (allocate<Double>()..value = replaceNullWith) : Pointer<Double>.fromAddress(0);
    switch(_type) {
      case OBXPropertyType.Float:
        return _unpack32(_curryWithDefault<OBX_float_array, Float>
          (bindings.obx_query_prop_float_find, ptr.cast<Float>(), "find float32"));
      case OBXPropertyType.Double:
        return _unpack64(_curryWithDefault<OBX_double_array, Double>
          (bindings.obx_query_prop_double_find, ptr.cast<Double>(), "find float64"));
      default:
        throw Exception('Property query: unsupported type (OBXPropertyType: ${_type})');
    }
  }

}

class StringPropertyQuery extends PropertyQuery {

  bool _caseSensitive = false;

  StringPropertyQuery (Pointer<Void> query, int propertyId, int obxType): super(query, propertyId, obxType);

  // distinct is already taken in the base type (can't overload with two params)
  // you could use that one instead
  set caseSensitive(bool caseSensitive) {
    _caseSensitive = caseSensitive;
    checkObx(bindings.obx_query_prop_distinct_case(_cProp, _distinct ? 1 : 0, _caseSensitive ? 1 : 0));
  }

  get caseSensitive => _caseSensitive;

  set distinct (bool d) {
    _distinct = d;
    checkObx(bindings.obx_query_prop_distinct_case(_cProp, d ? 1 : 0, _caseSensitive ? 1 : 0));
  }

  List<String> _unpack(Pointer<OBX_string_array> ptr) {
    try {
      return ptr.ref.items();
    }finally {
      bindings.obx_string_array_free(ptr);
    }
  }

  List<String> find({String replaceNullWith}) {
    final ptr = replaceNullWith != null ? Utf8.toUtf8(replaceNullWith).cast<Int8>() : Pointer<Int8>.fromAddress(0);
    return _unpack(_curryWithDefault<OBX_string_array, Int8>
      (bindings.obx_query_prop_string_find, ptr, "find utf8"));
  }

}
