part of query;

// Construct a tree from the first condition object
class QueryBuilder<T> {
  Store _store;
  int _entityId; // aka model id, entity id
  Condition _queryCondition;
  Pointer<Void> _cBuilder;
  OBXFlatbuffersManager _fbManager;

  QueryBuilder(this._store, this._fbManager, this._entityId, this._queryCondition);

  void _throwExceptionIfNecessary() {
    if (bindings.obx_qb_error_code(_cBuilder) != OBXError.OBX_SUCCESS) {
      final msg = cString(bindings.obx_qb_error_message(_cBuilder));
      throw ObjectBoxException(nativeMsg: msg);
    }
  }

  _createBuilder() => _cBuilder ??= bindings.obx_qb_create(_store.ptr, _entityId);

  Query build() {
    _createBuilder();

    if (0 == _queryCondition.apply(this, true)) {
      _throwExceptionIfNecessary();
    }

    try {
      return Query<T>._(_store, _fbManager, _cBuilder);
    } finally {
      checkObx(bindings.obx_qb_close(_cBuilder));
    }
  }

  QueryBuilder<T> order(QueryProperty p, {int flags = 0}) {
    if (p._entityId != _entityId) {
      throw Exception("Passed a property of another entity: ${p._entityId} instead of $_entityId");
    }
    _createBuilder();
    checkObx(bindings.obx_qb_order(_cBuilder, p._propertyId, flags));
    return this;
  }
}

/*  // Not done yet
    obx_qb_bytes_eq_dart_t obx_qb_bytes_equal;
    obx_qb_bytes_lt_gt_dart_t obx_qb_bytes_greater, obx_qb_bytes_less;

    obx_qb_param_alias_dart_t obx_qb_param_alias;
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
