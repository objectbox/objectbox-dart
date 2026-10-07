part of 'query.dart';

/// Allows overwriting a query condition value, making queries reusable.
///
/// Obtain a parameter with [Query.param]. The type of the returned parameter
/// depends on the type of the property and only offers setters that are
/// supported by conditions for that property type.
abstract class QueryParam {
  final Query _query;
  final int _entityId;
  final ModelProperty _model;
  final String? _alias;

  QueryParam._(this._query, this._entityId, this._model, this._alias);

  /// Calls [withoutAlias] or, if an alias is set, [withAlias] with the alias
  /// as a native string and checks the result.
  void _set(
    int Function(Pointer<OBX_query> cQuery, int entityId, int propertyId)
    withoutAlias,
    int Function(Pointer<OBX_query> cQuery, Pointer<Char> cAlias) withAlias,
  ) {
    final alias = _alias;
    final cQuery = _query._cQueryChecked;
    checkObx(
      alias == null
          ? withoutAlias(cQuery, _entityId, _model.id.id)
          : withNativeString(alias, (cAlias) => withAlias(cQuery, cAlias)),
    );
  }

  void _setString(String value) => withNativeString(
    value,
    (cValue) => _set(
      (q, e, p) => C.query_param_string(q, e, p, cValue),
      (q, a) => C.query_param_alias_string(q, a, cValue),
    ),
  );

  void _setStrings(List<String> values) => withNativeStrings(
    values,
    (ptr, size) => _set(
      (q, e, p) => C.query_param_strings(q, e, p, ptr, size),
      (q, a) => C.query_param_alias_strings(q, a, ptr, size),
    ),
  );

  void _set2Strings(String a, String b) => withNativeString(
    a,
    (cA) => withNativeString(
      b,
      (cB) => _set(
        (q, e, p) => C.query_param_2strings(q, e, p, cA, cB),
        (q, a) => C.query_param_alias_2strings(q, a, cA, cB),
      ),
    ),
  );

  void _setBytes(List<int> value) => withNativeBytes(
    Uint8List.fromList(value),
    (ptr, size) => _set(
      (q, e, p) => C.query_param_bytes(q, e, p, ptr, size),
      (q, a) => C.query_param_alias_bytes(q, a, ptr, size),
    ),
  );

  void _setInt(int value) => _set(
    (q, e, p) => C.query_param_int(q, e, p, value),
    (q, a) => C.query_param_alias_int(q, a, value),
  );

  void _setInts(List<int> values) {
    // Must match the types the query builder creates an int64 condition for
    // (see _IntegerListCondition._apply).
    if (_model.is64BitInt()) {
      final ptr = malloc<Int64>(values.length);
      try {
        for (var i = 0; i < values.length; i++) {
          ptr[i] = values[i];
        }
        _set(
          (q, e, p) => C.query_param_int64s(q, e, p, ptr, values.length),
          (q, a) => C.query_param_alias_int64s(q, a, ptr, values.length),
        );
      } finally {
        malloc.free(ptr);
      }
    } else {
      final ptr = malloc<Int32>(values.length);
      try {
        for (var i = 0; i < values.length; i++) {
          ptr[i] = values[i];
        }
        _set(
          (q, e, p) => C.query_param_int32s(q, e, p, ptr, values.length),
          (q, a) => C.query_param_alias_int32s(q, a, ptr, values.length),
        );
      } finally {
        malloc.free(ptr);
      }
    }
  }

  void _set2Ints(int a, int b) => _set(
    (q, e, p) => C.query_param_2ints(q, e, p, a, b),
    (q, alias) => C.query_param_alias_2ints(q, alias, a, b),
  );

  void _setDouble(double value) => _set(
    (q, e, p) => C.query_param_double(q, e, p, value),
    (q, a) => C.query_param_alias_double(q, a, value),
  );

  void _set2Doubles(double a, double b) => _set(
    (q, e, p) => C.query_param_2doubles(q, e, p, a, b),
    (q, alias) => C.query_param_alias_2doubles(q, alias, a, b),
  );

  void _setFloats(List<double> values) => withNativeFloats(
    values,
    (ptr, size) => _set(
      (q, e, p) => C.query_param_vector_float32(q, e, p, ptr, size),
      (q, a) => C.query_param_alias_vector_float32(q, a, ptr, size),
    ),
  );
}

/// Query parameter for [QueryStringProperty] conditions.
class QueryParamString extends QueryParam {
  QueryParamString._(super.query, super.entityId, super.model, super.alias)
    : super._();

  /// Sets the value of a condition with a single value.
  set value(String value) => _setString(value);

  /// Sets the values of a condition with a list of values, like `oneOf`.
  set values(List<String> values) => _setStrings(values);
}

/// Query parameter for [QueryByteVectorProperty] conditions.
class QueryParamBytes extends QueryParam {
  QueryParamBytes._(super.query, super.entityId, super.model, super.alias)
    : super._();

  /// Sets the value of a condition with a single value.
  set value(List<int> value) => _setBytes(value);
}

/// Query parameter for [QueryIntegerProperty] conditions.
class QueryParamInt extends QueryParam {
  QueryParamInt._(super.query, super.entityId, super.model, super.alias)
    : super._();

  /// Sets the value of a condition with a single value.
  set value(int value) => _setInt(value);

  /// Sets the values of a condition with a list of values, like `oneOf`.
  set values(List<int> values) => _setInts(values);

  /// Sets the values of a condition with two values, like `between`.
  void twoValues(int a, int b) => _set2Ints(a, b);
}

/// Query parameter for [QueryDoubleProperty] conditions.
class QueryParamDouble extends QueryParam {
  QueryParamDouble._(super.query, super.entityId, super.model, super.alias)
    : super._();

  /// Sets the value of a condition with a single value.
  set value(double value) => _setDouble(value);

  /// Sets the values of a condition with two values, like `between`.
  void twoValues(double a, double b) => _set2Doubles(a, b);
}

/// Query parameter for [QueryIntegerVectorProperty] conditions.
class QueryParamIntVector extends QueryParam {
  QueryParamIntVector._(super.query, super.entityId, super.model, super.alias)
    : super._();

  /// Sets the value of a condition with a single value, like `greaterThan`.
  set value(int value) => _setInt(value);
}

/// Query parameter for [QueryDoubleVectorProperty] conditions.
class QueryParamDoubleVector extends QueryParam {
  QueryParamDoubleVector._(
    super.query,
    super.entityId,
    super.model,
    super.alias,
  ) : super._();

  /// Sets the value of a condition with a single value, like `greaterThan`.
  set value(double value) => _setDouble(value);
}

/// Query parameter for [QueryHnswProperty] conditions.
class QueryParamHnsw extends QueryParamDoubleVector {
  QueryParamHnsw._(super.query, super.entityId, super.model, super.alias)
    : super._();

  /// Sets the values for the nearest neighbor condition.
  void nearestNeighborsF32(List<double> queryVector, int maxResultCount) {
    _setFloats(queryVector);
    _setInt(maxResultCount);
  }

  /// For a nearest neighbor condition
  /// ([QueryHnswProperty.nearestNeighborsF32]): sets the search level, the
  /// preferred way to trade search speed for quality (recall); see
  /// [VectorSearchLevel].
  ///
  /// This replaces the previously set oversample and rescore parameters
  /// ([oversampleFactor], [quantizationOversample], [rescore],
  /// [rescoreFactor]), so set those afterwards; it keeps the limits for
  /// searches with other conditions ([bruteForceMaxCandidates],
  /// [filteredSearchMaxNodes]).
  ///
  /// The other setters change single search parameters instead. They are for
  /// power users who tune the search for their data (e.g. by measuring recall
  /// and speed on a representative query set). A query starts with the values
  /// of the search level of the condition or of the index
  /// ([HnswIndex.searchLevel]).
  set searchLevel(VectorSearchLevel level) {
    final cLevel = level.toConstant();
    _set(
      (q, e, p) => C.query_param_vector_search_level(q, e, p, cLevel),
      (q, a) => C.query_param_alias_vector_search_level(q, a, cLevel),
    );
  }

  /// For a nearest neighbor condition: sets how many candidates the search
  /// explores per result for a higher recall, independent of quantization
  /// (must be at least 1).
  ///
  /// For power users; prefer the [searchLevel].
  set oversampleFactor(double factor) => _set(
    (q, e, p) => C.query_param_vector_oversample_factor(q, e, p, factor),
    (q, a) => C.query_param_alias_vector_oversample_factor(q, a, factor),
  );

  /// For a nearest neighbor condition with [HnswIndex.quantization]: sets the
  /// oversample factor that corrects for the quantization error only (0 or at
  /// least 1); 0 uses the one of the index
  /// ([HnswIndex.quantizationOversample]).
  ///
  /// For power users; prefer the [searchLevel].
  set quantizationOversample(double factor) => _set(
    (q, e, p) => C.query_param_vector_quantization_oversample(q, e, p, factor),
    (q, a) => C.query_param_alias_vector_quantization_oversample(q, a, factor),
  );

  /// For a nearest neighbor condition with [HnswIndex.quantization]: sets
  /// whether the search rescores its candidates with the exact vectors read
  /// from the objects (exact result distances and a higher recall), or returns
  /// the nearest by their quantized distance estimates (faster; the result
  /// distances are estimates).
  ///
  /// A non-zero [rescoreFactor] also turns rescoring on; the last one set wins,
  /// e.g. setting this to `false` after a factor turns rescoring off.
  ///
  /// For power users; prefer the [searchLevel].
  set rescore(bool rescore) => _set(
    (q, e, p) => C.query_param_vector_rescore(q, e, p, rescore),
    (q, a) => C.query_param_alias_vector_rescore(q, a, rescore),
  );

  /// For a nearest neighbor condition with [HnswIndex.quantization]: sets how
  /// many candidates are rescored: this factor times the result count of the
  /// candidates with the nearest estimates (0 or at least 1; at most the
  /// explored candidates); 0 uses the one of the index
  /// ([HnswIndex.quantizationRescoreFactor]).
  ///
  /// Like the `rescoreFactor` of [QueryHnswProperty.nearestNeighborsF32], a
  /// non-zero factor also turns rescoring on (see [rescore]), e.g. for the
  /// search levels that do not rescore otherwise (1-3); 0 keeps the rescore
  /// setting.
  ///
  /// For power users; prefer the [searchLevel].
  set rescoreFactor(double factor) => _set(
    (q, e, p) => C.query_param_vector_rescore_factor(q, e, p, factor),
    (q, a) => C.query_param_alias_vector_rescore_factor(q, a, factor),
  );

  /// For a nearest neighbor condition with other conditions: sets up to how
  /// many candidates of their lookups (indexes and relations) the nearest
  /// neighbors are found by brute force (exact distances) instead of by a graph
  /// search with a filter; 0 uses the value of the index
  /// ([HnswIndex.bruteForceMaxCandidates]).
  ///
  /// Higher values let more queries use brute force, but its costs grow with
  /// the candidates, while the graph search gets cheaper the more objects
  /// match.
  set bruteForceMaxCandidates(int maxCandidates) {
    checkUint32(maxCandidates, 'maxCandidates');
    _set(
      (q, e, p) => C.query_param_vector_brute_force_max_candidates(
        q,
        e,
        p,
        maxCandidates,
      ),
      (q, a) => C.query_param_alias_vector_brute_force_max_candidates(
        q,
        a,
        maxCandidates,
      ),
    );
  }

  /// For a nearest neighbor condition with other conditions: sets how many
  /// nodes the graph search (with a filter for the matching objects) explores
  /// at most; 0 uses the value of the index
  /// ([HnswIndex.filteredSearchMaxNodes]).
  ///
  /// Higher values increase the recall if few objects match, at the cost of
  /// speed; at the limit, fewer objects than requested may be found.
  set filteredSearchMaxNodes(int maxNodes) {
    checkUint32(maxNodes, 'maxNodes');
    _set(
      (q, e, p) =>
          C.query_param_vector_filtered_search_max_nodes(q, e, p, maxNodes),
      (q, a) =>
          C.query_param_alias_vector_filtered_search_max_nodes(q, a, maxNodes),
    );
  }
}

/// Query parameter for [QueryBooleanProperty] conditions.
class QueryParamBool extends QueryParam {
  QueryParamBool._(super.query, super.entityId, super.model, super.alias)
    : super._();

  /// Sets the value of a condition with a single value.
  set value(bool value) => _setInt(value ? 1 : 0);
}

/// Query parameter for [QueryStringVectorProperty] conditions.
class QueryParamStringVector extends QueryParam {
  QueryParamStringVector._(
    super.query,
    super.entityId,
    super.model,
    super.alias,
  ) : super._();

  /// Sets the value of a condition with a single value, like
  /// `containsElement`.
  set value(String value) => _setString(value);
}

/// Query parameter for [QueryFlexVectorProperty] conditions.
class QueryParamFlexVector extends QueryParam {
  QueryParamFlexVector._(super.query, super.entityId, super.model, super.alias)
    : super._();

  /// Sets the value of a condition with a single value, like
  /// `containsElement`.
  set value(String value) => _setString(value);
}

/// Query parameter for [QueryFlexValueProperty] conditions.
class QueryParamFlexValue extends QueryParam {
  QueryParamFlexValue._(super.query, super.entityId, super.model, super.alias)
    : super._();

  /// Sets the value of a condition with a single value, like `equals`.
  set value(String value) => _setString(value);
}

/// Query parameter for [QueryFlexMapProperty] conditions.
class QueryParamFlexMap extends QueryParam {
  QueryParamFlexMap._(super.query, super.entityId, super.model, super.alias)
    : super._();

  /// Sets the key of a condition created with a key, like `containsElement`.
  set valueString(String value) => _setString(value);

  /// Sets the key and value of a condition created with a string key and
  /// string value, like `equalsKeyValueString` or `greaterKeyValueString`.
  void twoValuesString(String key, String value) => _set2Strings(key, value);
}
