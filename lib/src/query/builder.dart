part of query;

// Construct a tree from the first condition object
class QueryBuilder<T> extends _QueryBuilder<T> {
  final OBXFlatbuffersManager<T> _fbManager;

  QueryBuilder(Store store, this._fbManager, int entityId, Condition /*?*/ qc)
      : super(store, entityId, qc,
            bindings.obx_query_builder(store.ptr, entityId));

  Query<T> build() {
    _applyCondition();

    try {
      return Query<T>._(_store, _fbManager, _cBuilder, _entityId);
    } finally {
      _close();
    }
  }

  QueryBuilder<T> order(QueryProperty p, {int flags = 0}) {
    _throwIfOtherEntity(p);
    checkObx(bindings.obx_qb_order(_cBuilder, p._propertyId, flags));
    return this;
  }
}

/// Basic/linked query builder only has limited methods: link()
class _QueryBuilder<T> {
  final Store _store;
  final int _entityId; // aka model id, entity id
  final Condition /*?*/ _queryCondition;
  Pointer<OBX_query_builder> /*?*/ _cBuilder;
  final _innerQBs = <_QueryBuilder>[];

  _QueryBuilder(
      this._store, this._entityId, this._queryCondition, this._cBuilder) {
    checkObxPtr(_cBuilder, 'failed to create QueryBuilder');
  }

  _QueryBuilder._linkProperty(
      _QueryBuilder srcQB, int relPropertyId, this._queryCondition)
      : _store = srcQB._store,
        _entityId = srcQB._store.entityDef<T>().model.id.id,
        _cBuilder = checkObxPtr(
            bindings.obx_qb_link_property(srcQB._cBuilder, relPropertyId),
            'failed to create QueryBuilder') {
    _applyCondition();
  }

  void _close() {
    _innerQBs.forEach((iqb) => iqb._close());
    checkObx(bindings.obx_qb_close(_cBuilder));
    _cBuilder = null;
  }

  void _throwExceptionIfNecessary() {
    if (bindings.obx_qb_error_code(_cBuilder) != OBX_SUCCESS) {
      final msg = cString(bindings.obx_qb_error_message(_cBuilder));
      throw ObjectBoxException(
          dartMsg: 'Query building failed', nativeMsg: msg);
    }
  }

  void _throwIfOtherEntity(QueryProperty p) {
    if (p._entityId != _entityId) {
      throw Exception(
          'Passed a property of another entity: ${p._entityId} instead of $_entityId');
    }
  }

  void _applyCondition() {
    if (_queryCondition != null &&
        0 == _queryCondition /*!*/ .apply(this, true)) {
      _throwExceptionIfNecessary();
    }
  }

  _QueryBuilder<TargetEntityT> link<TargetEntityT>(
      QueryRelationProperty<TargetEntityT> rel,
      [Condition /*?*/ qc]) {
    _throwIfOtherEntity(rel);
    final innerQB =
        _QueryBuilder<TargetEntityT>._linkProperty(this, rel._propertyId, qc);
    _innerQBs.add(innerQB);
    return innerQB;
  }
}
