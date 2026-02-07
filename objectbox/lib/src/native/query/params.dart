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
    QueryProperty<EntityT, DartType> prop, {
    String? alias,
  }) => QueryParam._(
    this,
    InternalStoreAccess.entityDef<EntityT>(_store).model.id.id,
    prop,
    alias,
  );
}

/// QueryParam
class QueryParam<DartType> {
  final Query _query;
  final int _entityId;
  final QueryProperty _prop;
  final String? _alias;

  QueryParam._(this._query, this._entityId, this._prop, this._alias);

  void _setString(String value) {
    if (_alias == null) {
      withNativeString(
        value,
        (Pointer<Char> cStr) => checkObx(
          C.query_param_string(
            _query._cQueryChecked,
            _entityId,
            _prop._model.id.id,
            cStr,
          ),
        ),
      );
    } else {
      withNativeStrings(
        [_alias, value],
        (Pointer<Pointer<Char>> ptr, int size) => checkObx(
          C.query_param_alias_string(_query._cQueryChecked, ptr[0], ptr[1]),
        ),
      );
    }
  }
}

/// QueryParam for string properties
extension QueryParamString on QueryParam<String> {
  set value(String value) => _setString(value);

  set values(List<String> values) => withNativeStrings(
    values,
    (Pointer<Pointer<Char>> ptr, int size) => checkObx(
      (_alias == null)
          ? C.query_param_strings(
            _query._cQueryChecked,
            _entityId,
            _prop._model.id.id,
            ptr,
            size,
          )
          : withNativeString(
            _alias,
            (Pointer<Char> cAlias) => C.query_param_alias_strings(
              _query._cQueryChecked,
              cAlias,
              ptr,
              size,
            ),
          ),
    ),
  );
}

/// QueryParam for byte vector properties
extension QueryParamBytes on QueryParam<List<int>> {
  set value(List<int> value) => withNativeBytes(
    Uint8List.fromList(value),
    (Pointer<Uint8> ptr, int size) => checkObx(
      (_alias == null)
          ? C.query_param_bytes(
            _query._cQueryChecked,
            _entityId,
            _prop._model.id.id,
            ptr,
            size,
          )
          : withNativeString(
            _alias,
            (Pointer<Char> cAlias) => C.query_param_alias_bytes(
              _query._cQueryChecked,
              cAlias,
              ptr,
              size,
            ),
          ),
    ),
  );
}

/// QueryParam for int properties
extension QueryParamInt on QueryParam<int> {
  set value(int value) => checkObx(
    (_alias == null)
        ? C.query_param_int(
          _query._cQueryChecked,
          _entityId,
          _prop._model.id.id,
          value,
        )
        : withNativeString(
          _alias,
          (Pointer<Char> cAlias) =>
              C.query_param_alias_int(_query._cQueryChecked, cAlias, value),
        ),
  );

  set values(List<int> values) {
    // Must match the types the query builder creates an int64 condition for
    // (see _IntegerListCondition._apply).
    final is64bit = _prop._model.is64BitInt();
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
        checkObx(
          is64bit
              ? C.query_param_int64s(
                _query._cQueryChecked,
                _entityId,
                _prop._model.id.id,
                ptr as Pointer<Int64>,
                values.length,
              )
              : C.query_param_int32s(
                _query._cQueryChecked,
                _entityId,
                _prop._model.id.id,
                ptr as Pointer<Int32>,
                values.length,
              ),
        );
      } else {
        withNativeString(
          _alias,
          (Pointer<Char> cAlias) => checkObx(
            is64bit
                ? C.query_param_alias_int64s(
                  _query._cQueryChecked,
                  cAlias,
                  ptr as Pointer<Int64>,
                  values.length,
                )
                : C.query_param_alias_int32s(
                  _query._cQueryChecked,
                  cAlias,
                  ptr as Pointer<Int32>,
                  values.length,
                ),
          ),
        );
      }
    } finally {
      malloc.free(ptr);
    }
  }

  /// set values for condition consisting of two values
  void twoValues(int a, int b) => checkObx(
    (_alias == null)
        ? C.query_param_2ints(
          _query._cQueryChecked,
          _entityId,
          _prop._model.id.id,
          a,
          b,
        )
        : withNativeString(
          _alias,
          (Pointer<Char> cAlias) =>
              C.query_param_alias_2ints(_query._cQueryChecked, cAlias, a, b),
        ),
  );
}

/// QueryParam for double properties
extension QueryParamDouble on QueryParam<double> {
  set value(double value) => checkObx(
    (_alias == null)
        ? C.query_param_double(
          _query._cQueryChecked,
          _entityId,
          _prop._model.id.id,
          value,
        )
        : withNativeString(
          _alias,
          (Pointer<Char> cAlias) =>
              C.query_param_alias_double(_query._cQueryChecked, cAlias, value),
        ),
  );

  /// set values for condition consisting of two values
  void twoValues(double a, double b) => checkObx(
    (_alias == null)
        ? C.query_param_2doubles(
          _query._cQueryChecked,
          _entityId,
          _prop._model.id.id,
          a,
          b,
        )
        : withNativeString(
          _alias,
          (Pointer<Char> cAlias) =>
              C.query_param_alias_2doubles(_query._cQueryChecked, cAlias, a, b),
        ),
  );

  /// Set values for the nearest neighbor condition.
  void nearestNeighborsF32(List<double> queryVector, int maxResultCount) {
    withNativeFloats(queryVector, (floatsPtr, size) {
      if (_alias == null) {
        checkObx(
          C.query_param_vector_float32(
            _query._cQueryChecked,
            _entityId,
            _prop._model.id.id,
            floatsPtr,
            size,
          ),
        );
        checkObx(
          C.query_param_int(
            _query._cQueryChecked,
            _entityId,
            _prop._model.id.id,
            maxResultCount,
          ),
        );
      } else {
        withNativeString(_alias, (aliasPtr) {
          checkObx(
            C.query_param_alias_vector_float32(
              _query._cQueryChecked,
              aliasPtr,
              floatsPtr,
              size,
            ),
          );
          checkObx(
            C.query_param_alias_int(
              _query._cQueryChecked,
              aliasPtr,
              maxResultCount,
            ),
          );
        });
      }
    });
  }

  /// Calls [byProperty] or, if this has an alias, [byAlias] and checks the
  /// result.
  void _setVectorSearchParam(
    int Function(Pointer<OBX_query> cQuery, int entityId, int propertyId)
    byProperty,
    int Function(Pointer<OBX_query> cQuery, Pointer<Char> cAlias) byAlias,
  ) {
    final alias = _alias;
    checkObx(
      (alias == null)
          ? byProperty(_query._cQueryChecked, _entityId, _prop._model.id.id)
          : withNativeString(
            alias,
            (Pointer<Char> cAlias) => byAlias(_query._cQueryChecked, cAlias),
          ),
    );
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
    _setVectorSearchParam(
      (q, e, p) => C.query_param_vector_search_level(q, e, p, cLevel),
      (q, a) => C.query_param_alias_vector_search_level(q, a, cLevel),
    );
  }

  /// For a nearest neighbor condition: sets how many candidates the search
  /// explores per result for a higher recall, independent of quantization
  /// (must be at least 1).
  ///
  /// For power users; prefer the [searchLevel].
  set oversampleFactor(double factor) => _setVectorSearchParam(
    (q, e, p) => C.query_param_vector_oversample_factor(q, e, p, factor),
    (q, a) => C.query_param_alias_vector_oversample_factor(q, a, factor),
  );

  /// For a nearest neighbor condition with [HnswIndex.quantization]: sets the
  /// oversample factor that corrects for the quantization error only (0 or at
  /// least 1); 0 uses the one of the index
  /// ([HnswIndex.quantizationOversample]).
  ///
  /// For power users; prefer the [searchLevel].
  set quantizationOversample(double factor) => _setVectorSearchParam(
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
  set rescore(bool rescore) => _setVectorSearchParam(
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
  set rescoreFactor(double factor) => _setVectorSearchParam(
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
    _setVectorSearchParam(
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
    _setVectorSearchParam(
      (q, e, p) =>
          C.query_param_vector_filtered_search_max_nodes(q, e, p, maxNodes),
      (q, a) =>
          C.query_param_alias_vector_filtered_search_max_nodes(q, a, maxNodes),
    );
  }
}

/// QueryParam for boolean properties
extension QueryParamBool on QueryParam<bool> {
  set value(bool value) => checkObx(
    (_alias == null)
        ? C.query_param_int(
          _query._cQueryChecked,
          _entityId,
          _prop._model.id.id,
          value ? 1 : 0,
        )
        : withNativeString(
          _alias,
          (Pointer<Char> cAlias) => C.query_param_alias_int(
            _query._cQueryChecked,
            cAlias,
            value ? 1 : 0,
          ),
        ),
  );
}

/// QueryParam for flex vector properties
extension QueryParamFlexVector on QueryParam<List<dynamic>> {
  set valueString(String value) => _setString(value);

  set valueInt(int value) => _setString('$value');
}

/// QueryParam for flex value properties
extension QueryParamFlexValue on QueryParam<dynamic> {
  set valueString(String value) => _setString(value);

  set valueInt(int value) => _setString('$value');
}

/// QueryParam for flex map properties
extension QueryParamFlexMap on QueryParam<Map<String, dynamic>> {
  set valueString(String value) => _setString(value);
}
