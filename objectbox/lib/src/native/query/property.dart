part of 'query.dart';

/// Property query base.
class PropertyQuery<T> implements Finalizable {
  final Query<dynamic> _query;

  /// Pointer to the native instance. Use [_ptr] for safe access instead.
  final Pointer<OBX_query_prop> _cProp;

  /// Runs native close function on [_cProp] if this is garbage collected.
  ///
  /// Keeps the finalizer itself reachable (static), otherwise it might be
  /// disposed of before the finalizer callback gets a chance to run.
  static final _finalizer =
      NativeFinalizer(C.addresses.query_prop_close.cast());

  bool _closed = false;
  final int _type;
  bool _distinct = false;
  bool _caseSensitive = false;

  PropertyQuery._(this._query, this._cProp, this._type) {
    checkObxPtr(_cProp, 'property query');
    _finalizer.attach(this, _cProp.cast(), detach: this, externalSize: 64);
  }

  @pragma("vm:prefer-inline")
  Pointer<OBX_query_prop> get _ptr {
    _query._checkOpen();
    if (_closed) {
      throw StateError(
          'Property query already closed, cannot execute any actions');
    }
    return _cProp;
  }

  /// Close the property query, freeing its resources
  void close() {
    if (!_closed) {
      _closed = true;
      _finalizer.detach(this);
      checkObx(C.query_prop_close(_cProp));
    }
  }

  int _count() {
    final ptr = malloc<Uint64>();
    try {
      checkObx(C.query_prop_count(_ptr, ptr));
      return ptr.value;
    } finally {
      malloc.free(ptr);
    }
  }

  List<R> _find<R, StructT extends NativeType, ValT extends NativeType>(
      Pointer<StructT> Function(Pointer<OBX_query_prop>, Pointer<ValT>) findFn,
      Pointer<ValT>? cDefault,
      List<R> Function(Pointer<StructT>) listReadFn,
      void Function(Pointer<StructT>) listFreeFn) {
    Pointer<StructT> cItems = nullptr;
    try {
      cItems = checkObxPtr(
          findFn(_ptr, cDefault ?? nullptr), 'Property query failed');
      return listReadFn(cItems);
    } finally {
      if (cDefault != null) malloc.free(cDefault);
      if (cItems != nullptr) listFreeFn(cItems);
    }
  }

  double _average() {
    final ptr = malloc<Double>();
    try {
      checkObx(C.query_prop_avg(_ptr, ptr, nullptr));
      return ptr.value;
    } finally {
      malloc.free(ptr);
    }
  }
}

/// "Property query" for an integer field. Created by [Query.property()].
extension IntegerPropertyQuery on PropertyQuery<int> {
  int _op(
      int Function(Pointer<OBX_query_prop>, Pointer<Int64>, Pointer<Int64>)
          fn) {
    final ptr = malloc<Int64>();
    try {
      checkObx(fn(_ptr, ptr, nullptr));
      return ptr.value;
    } finally {
      malloc.free(ptr);
    }
  }

  /// Average value of the property over all objects matching the query.
  double average() => _average();

  /// Returns the count of non-null values.
  int count() => _count();

  /// Get the status of "distinct-values" configuration.
  bool get distinct => _distinct;

  /// Set to only return distinct values.
  ///
  /// E.g. `[1,2,3]` instead of `[1,1,2,3,3,3]`.
  /// Strings default to case-insensitive comparison.
  set distinct(bool d) {
    _distinct = d;
    checkObx(C.query_prop_distinct(_ptr, d));
  }

  /// Minimum value of the property over all objects matching the query.
  int min() => _op(C.query_prop_min_int);

  /// Maximum value of the property over all objects matching the query.
  int max() => _op(C.query_prop_max_int);

  /// Sum of all property values over objects matching the query.
  int sum() => _op(C.query_prop_sum_int);

  /// Returns values of this property matching the query.
  ///
  /// Results are in no particular order. Excludes null values unless you
  /// specify [replaceNullWith].
  List<int> find({int? replaceNullWith}) {
    switch (_type) {
      case OBXPropertyType.Bool:
      case OBXPropertyType.Byte: // Int8
        final cDefault = replaceNullWith == null
            ? null
            : (malloc<Int8>()..value = replaceNullWith);
        return _find(
            C.query_prop_find_int8s,
            cDefault,
            (Pointer<OBX_int8_array> cItems) =>
                cItems.ref.items.asTypedList(cItems.ref.count).toList(),
            C.int8_array_free);
      case OBXPropertyType.Char:
      case OBXPropertyType.Short: // Int16
        final cDefault = replaceNullWith == null
            ? null
            : (malloc<Int16>()..value = replaceNullWith);
        return _find(
            C.query_prop_find_int16s,
            cDefault,
            (Pointer<OBX_int16_array> cItems) =>
                cItems.ref.items.asTypedList(cItems.ref.count).toList(),
            C.int16_array_free);
      case OBXPropertyType.Int: // Int32
        final cDefault = replaceNullWith == null
            ? null
            : (malloc<Int32>()..value = replaceNullWith);
        return _find(
            C.query_prop_find_int32s,
            cDefault,
            (Pointer<OBX_int32_array> cItems) =>
                cItems.ref.items.asTypedList(cItems.ref.count).toList(),
            C.int32_array_free);
      case OBXPropertyType.Long: // Int64
        final cDefault = replaceNullWith == null
            ? null
            : (malloc<Int64>()..value = replaceNullWith);
        return _find(
            C.query_prop_find_int64s,
            cDefault,
            (Pointer<OBX_int64_array> cItems) =>
                cItems.ref.items.asTypedList(cItems.ref.count).toList(),
            C.int64_array_free);
      default:
        throw UnsupportedError(
            'Property query: unsupported type (OBXPropertyType: $_type)');
    }
  }
}

/// "Property query" for a double field. Created by [Query.property()].
extension DoublePropertyQuery on PropertyQuery<double> {
  double _op(
      int Function(Pointer<OBX_query_prop>, Pointer<Double>, Pointer<Int64>)
          fn) {
    final ptr = malloc<Double>();
    try {
      checkObx(fn(_ptr, ptr, nullptr));
      return ptr.value;
    } finally {
      malloc.free(ptr);
    }
  }

  /// Average value of the property over all objects matching the query.
  double average() => _average();

  /// Returns the count of non-null values.
  int count() => _count();

  /// Get the status of "distinct-values" configuration.
  bool get distinct => _distinct;

  /// Set to only return distinct values.
  ///
  /// E.g. `[1,2,3]` instead of `[1,1,2,3,3,3]`.
  /// Strings default to case-insensitive comparison.
  set distinct(bool d) {
    _distinct = d;
    checkObx(C.query_prop_distinct(_ptr, d));
  }

  /// Minimum value of the property over all objects matching the query.
  double min() => _op(C.query_prop_min);

  /// Maximum value of the property over all objects matching the query.
  double max() => _op(C.query_prop_max);

  /// Sum of all property values over objects matching the query.
  double sum() => _op(C.query_prop_sum);

  /// Returns values of this property matching the query.
  ///
  /// Results are in no particular order. Excludes null values unless you
  /// specify [replaceNullWith].
  List<double> find({double? replaceNullWith}) {
    switch (_type) {
      case OBXPropertyType.Float:
        final cDefault = replaceNullWith == null
            ? null
            : (malloc<Float>()..value = replaceNullWith);
        return _find(
            C.query_prop_find_floats,
            cDefault,
            (Pointer<OBX_float_array> cItems) =>
                cItems.ref.items.asTypedList(cItems.ref.count).toList(),
            C.float_array_free);
      case OBXPropertyType.Double:
        final cDefault = replaceNullWith == null
            ? null
            : (malloc<Double>()..value = replaceNullWith);
        return _find(
            C.query_prop_find_doubles,
            cDefault,
            (Pointer<OBX_double_array> cItems) =>
                cItems.ref.items.asTypedList(cItems.ref.count).toList(),
            C.double_array_free);
      default:
        throw UnsupportedError(
            'Property query: unsupported type (OBXPropertyType: $_type)');
    }
  }
}

/// "Property query" for a string field. Created by [Query.property()].
extension StringPropertyQuery on PropertyQuery<String> {
  /// Use case-sensitive comparison when querying [distinct] values.
  /// E.g. returning "foo","Foo","FOO" instead of just "foo".
  set caseSensitive(bool caseSensitive) {
    _caseSensitive = caseSensitive;
    checkObx(C.query_prop_distinct_case(_ptr, _distinct, _caseSensitive));
  }

  /// Get status of the case-sensitive configuration.
  bool get caseSensitive => _caseSensitive;

  /// Get the status of "distinct-values" configuration.
  bool get distinct => _distinct;

  /// Set to only return distinct values.
  ///
  /// E.g. `[foo, bar]` instead of `[foo, bar, bar, bar, foo]`.
  /// Strings default to case-insensitive comparison.
  set distinct(bool d) {
    _distinct = d;
    checkObx(C.query_prop_distinct_case(_ptr, d, _caseSensitive));
  }

  /// Returns the count of non-null values.
  int count() => _count();

  /// Returns values of this property matching the query.
  ///
  /// Results are in no particular order. Excludes null values unless you
  /// specify [replaceNullWith].
  List<String> find({String? replaceNullWith}) {
    final cDefault = replaceNullWith?.toNativeUtf8().cast<Char>();

    return _find(
        C.query_prop_find_strings,
        cDefault,
        (Pointer<OBX_string_array> cItems) => cItems.toDartStrings(),
        C.string_array_free);
  }
}
