part of query;

// Construct a tree from the first condition object
class QueryBuilder<T> {
  final Store _store;
  final int _entityId; // aka model id, entity id
  final Condition _queryCondition;
  Pointer<OBX_query_builder> _cBuilder;
  final OBXFlatbuffersManager _fbManager;

  QueryBuilder(this._store, this._fbManager, this._entityId,
      [this._queryCondition]);

  void _throwExceptionIfNecessary() {
    if (bindings.obx_qb_error_code(_cBuilder) != OBX_SUCCESS) {
      final msg = cString(bindings.obx_qb_error_message(_cBuilder));
      throw ObjectBoxException(nativeMsg: msg);
    }
  }

  Pointer<OBX_query_builder> _createBuilder() =>
      _cBuilder ??= bindings.obx_query_builder(_store.ptr, _entityId);

  Query build() {
    _createBuilder();

    if (_queryCondition != null && 0 == _queryCondition.apply(this, true)) {
      _throwExceptionIfNecessary();
    }

    try {
      return Query<T>._(_store, _fbManager, _cBuilder, _entityId);
    } finally {
      checkObx(bindings.obx_qb_close(_cBuilder));
    }
  }

  QueryBuilder<T> order(QueryProperty p, {int flags = 0}) {
    if (p._entityId != _entityId) {
      throw Exception(
          'Passed a property of another entity: ${p._entityId} instead of $_entityId');
    }
    _createBuilder();
    checkObx(bindings.obx_qb_order(_cBuilder, p._propertyId, flags));
    return this;
  }
}
