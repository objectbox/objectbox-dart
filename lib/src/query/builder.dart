part of query;

// Construct a tree from the first condition object
class QueryBuilder<T> {
  Store _store;
  int _entityId; // aka model id, entity id
  QueryCondition _queryCondition;
  Pointer<Void> _cBuilder;
  OBXFlatbuffersManager _fbManager;

  QueryBuilder(this._store, this._fbManager, this._entityId, this._queryCondition);

  void _throwExceptionIfNecessary() {
    if (bindings.obx_qb_error_code(_cBuilder) != OBXError.OBX_SUCCESS) {
      final msg = Utf8.fromUtf8(bindings.obx_qb_error_message(_cBuilder).cast<Utf8>());
      throw ObjectBoxException("$msg");
    }
  }

  int _create(QueryCondition qc) {
    Condition condition = qc._condition;
    int propertyId = qc._propertyId;

    try {
      switch (condition._op) {
        case ConditionOp.nil:
          return condition._nullness(_cBuilder, propertyId, bindings.obx_qb_null);
        case ConditionOp.not_nil:
          return condition._nullness(_cBuilder, propertyId, bindings.obx_qb_not_null);
        default:
          break;
      }
      return condition.apply(_cBuilder, propertyId);
    }finally {
      _throwExceptionIfNecessary();
    }
  }

  int _createGroup(List<int> list, obx_qb_join_op_dart_t func) {
    final size = list.length;
    final intArrayPtr = Pointer<Int32>.allocate(count: size);
    try {
      for(int i = 0; i < size; ++i) {
        intArrayPtr.elementAt(i).store(list[i]);
      }
      return func(_cBuilder, intArrayPtr, size);
    }finally {
      intArrayPtr.free();
      _throwExceptionIfNecessary();
    }
  }

  int _createAllGroup(List<QueryCondition> list) {
    return _createGroup(list.map((qc) => qc._root ? _create(qc) : _parse(qc)).toList(), bindings.obx_qb_all);
  }

  int _createAnyGroup(List<int> list) {
    return _createGroup(list, bindings.obx_qb_any);
  }

  int _parse(QueryCondition qc) {

    assert (qc != null && _cBuilder != null);

    final anyGroup = qc._anyGroups;

    if (anyGroup == null) {
      return _create(qc);
    }

    if (anyGroup.length == 1) {
      if (anyGroup[0].length == 1) {
        return _create(qc);
      }else /* if anyGroup.length == 1 then only apply 'all' */ {
        return _createAllGroup(anyGroup[0]);
      }
    }else /* if anyGroup.length > 1 then apply 'any' */ {
      return _createAnyGroup(anyGroup.map((qcList) => _createAllGroup(qcList)).toList());
    }
  }

  Query build() {
    _cBuilder = bindings.obx_qb_create(_store.ptr, _entityId);

    // TODO pass an empty map to collect properytIds per OrderFlag in `_parse`
    // parse the anyGroup tree in recursion
    _parse(_queryCondition); // ignore the return value

    try {
      return Query<T>._(_store, _fbManager, _cBuilder);
    }finally {
      checkObx(bindings.obx_qb_close(_cBuilder));
    }
  }
}

/*  // Not done yet
    // * = can't test, no support yet, for Double, Long, Boolean, Byte, or Vector... etc.
    * obx_qb_cond_operator_in_dart_t<Int64> obx_qb_int64_in, obx_qb_int64_not_in;
    * obx_qb_cond_operator_in_dart_t<Int32> obx_qb_int32_in, obx_qb_int32_not_in;
    * obx_qb_string_in_dart_t obx_qb_string_in;

    * obx_qb_string_lt_gt_op_dart_t obx_qb_string_greater, obx_qb_string_less;

    obx_qb_bytes_eq_dart_t obx_qb_bytes_equal;
    obx_qb_bytes_lt_gt_dart_t obx_qb_bytes_greater, obx_qb_bytes_less;

    obx_qb_param_alias_dart_t obx_qb_param_alias;

    obx_qb_order_dart_t obx_qb_order;
*/

//////
//////

/** Inspiration
    Modifier and Type	Method	Description
    <TARGET> QueryBuilder<TARGET>	backlink​(RelationInfo<TARGET,?> relationInfo)
    Creates a backlink (reversed link) to another entity, for which you also can describe conditions using the returned builder.
    void	close()
 ** QueryBuilder<T>	eager​(int limit, RelationInfo relationInfo, RelationInfo... more)
    Like eager(RelationInfo, RelationInfo[]), but limits eager loading to the given count.
 ** QueryBuilder<T>	eager​(RelationInfo relationInfo, RelationInfo... more)
    Specifies relations that should be resolved eagerly.
 ** QueryBuilder<T>	filter​(QueryFilter<T> filter) // dart has built-in higher order functions
    Sets a filter that executes on primary query results (returned from the db core) on a Java level.
    <TARGET> QueryBuilder<TARGET>	link​(RelationInfo<?,TARGET> relationInfo)
    Creates a link to another entity, for which you also can describe conditions using the returned builder.
 ** QueryBuilder<T>	order​(Property<T> property)
    Specifies given property to be used for sorting.
 ** QueryBuilder<T>	order​(Property<T> property, int flags)
    Defines the order with which the results are ordered (default: none).
 ** QueryBuilder<T>	orderDesc​(Property<T> property)
    Specifies given property in descending order to be used for sorting.
 ** QueryBuilder<T>	parameterAlias​(java.lang.String alias)
    Assigns the given alias to the previous condition.
 ** QueryBuilder<T>	sort​(java.util.Comparator<T> comparator)
 */