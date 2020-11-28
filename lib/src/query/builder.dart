part of query;

// Construct a tree from the first condition object
class QueryBuilder<T> {
  final Store _store;
  final int _entityId; // aka model id, entity id
  final Condition /*?*/ _queryCondition;
  final Pointer<OBX_query_builder> _cBuilder;
  final OBXFlatbuffersManager<T> _fbManager;

  QueryBuilder(
      this._store, this._fbManager, this._entityId, this._queryCondition)
      : _cBuilder = checkObxPtr(
            bindings.obx_query_builder(_store.ptr, _entityId),
            'failed to create QueryBuilder');

  void _throwExceptionIfNecessary() {
    if (bindings.obx_qb_error_code(_cBuilder) != OBX_SUCCESS) {
      final msg = cString(bindings.obx_qb_error_message(_cBuilder));
      throw ObjectBoxException(
          dartMsg: 'Query building failed', nativeMsg: msg);
    }
  }

  Query<T> build() {
    if (_queryCondition != null &&
        0 == _queryCondition /*!*/ .apply(this, true)) {
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
    checkObx(bindings.obx_qb_order(_cBuilder, p._propertyId, flags));
    return this;
  }
}
