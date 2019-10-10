part of query;

// Construct a tree from the first condition object
class QueryBuilder<T> {
  Box<T> _box;
  Store _store;
  int _entityId; // aka model id, entity id
  QueryCondition _queryCondition;
  Pointer<Void> _cBuilder;

  QueryBuilder(this._box, this._store, this._entityId, this._queryCondition);

  void _throwExceptionIfNecessary() {
    if (bindings.obx_qb_error_code(_cBuilder) != OBXError.OBX_SUCCESS) {
      final msg = Utf8.fromUtf8(bindings.obx_qb_error_message(_cBuilder).cast<Utf8>());
      throw ObjectBoxException("$msg");
    }
  }

  int _create(QueryCondition qc) {
    Condition condition = qc._condition;
    ConditionType type = condition._type;
    ConditionOp   op   = condition._op;
    int propertyId = qc._propertyId;

    // TODO remove debug code
    // print("type: ${type.toString()}, op: ${op.toString()}");

    // do the typecasting here, we can't generalize to an op method
    // due to the differing number of parameters per ConditionType
    try {
      switch (type) {
        case ConditionType.string:
          {
            final stringCondition = qc._condition as StringCondition;
            // why can't we have java-style enums on steroids on dart?
            switch (op) {
              case ConditionOp.eq:
                return stringCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_string_equal);
              case ConditionOp.not_eq:
                return stringCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_string_not_equal);
              case ConditionOp.string_contains:
                return stringCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_string_contains);
              case ConditionOp.string_starts:
                return stringCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_string_starts_with);
              case ConditionOp.string_ends:
                return stringCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_string_ends_with);
              case ConditionOp.lt:
                return stringCondition._opWithEqual(
                    _cBuilder, qc, bindings.obx_qb_string_less);
              case ConditionOp.gt:
                return stringCondition._opWithEqual(
                    _cBuilder, qc, bindings.obx_qb_string_greater);
            }
            break;
          }
        case ConditionType.int64: // current default for int
          {
            final intCondition = qc._condition as IntegerCondition;
            switch (op) {
              case ConditionOp.eq:
                return intCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_int_equal);
              case ConditionOp.not_eq:
                return intCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_int_not_equal);
              case ConditionOp.gt:
                return intCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_int_greater);
              case ConditionOp.lt:
                return intCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_int_less);
            }
            break;
          }
        case ConditionType.float64:
          {
            final doubleCondition = qc._condition as DoubleCondition;
            switch (op) {
              case ConditionOp.gt:
                return doubleCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_double_greater);
              case ConditionOp.lt:
                return doubleCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_double_less);
              default:
                break;
            }
            break;
          }
      }

      switch (op) {
        case ConditionOp.nil:
          return condition._nullness(_cBuilder, qc, bindings.obx_qb_null);
        case ConditionOp.not_nil:
          return condition._nullness(_cBuilder, qc, bindings.obx_qb_not_null);
        case ConditionOp.tween:
          {
            switch (type) {
              case ConditionType.int64: // current default for int
                final c = qc._condition as Condition<int>;
                return bindings.obx_qb_int_between(
                    _cBuilder, propertyId, c._value, c._value2);
              case ConditionType.float64:
                final c = qc._condition as Condition<double>;
                return bindings.obx_qb_double_between(
                    _cBuilder, propertyId, c._value, c._value2);
            }
            break;
          }
        case ConditionOp.inside:
          {
            switch (type) {
              case ConditionType.int32:
                final c = qc._condition as IntegerCondition;
                return c._opList32(_cBuilder, qc, bindings.obx_qb_int32_in);
              case ConditionType.int64:
                final c = qc._condition as IntegerCondition;
                return c._opList64(_cBuilder, qc, bindings.obx_qb_int64_in);
              case ConditionType.string:
                final c = qc._condition as StringCondition;
                return c._inside(_cBuilder, qc); // bindings.obx_qb_string_in
            }
            break;
          }
        case ConditionOp.not_in:
          {
            switch (type) {
              case ConditionType.int32:
                final c = qc._condition as IntegerCondition;
                return c._opList32(_cBuilder, qc, bindings.obx_qb_int32_not_in);
              case ConditionType.int64:
                final c = qc._condition as IntegerCondition;
                return c._opList64(_cBuilder, qc, bindings.obx_qb_int64_not_in);
            }
            break;
          }
      }
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
      return Query<T>._(_box, _cBuilder);
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