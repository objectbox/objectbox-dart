part of query;

/// Query builder allows creating reusable queries.
class QueryBuilder<T> extends _QueryBuilder<T> {
  /// Start creating a query.
  QueryBuilder(Store store, EntityDefinition<T> entity, Condition /*?*/ qc)
      : super(
            store,
            entity,
            qc,
            C.query_builder(
                InternalStoreAccess.ptr(store), entity.model.id.id));

  /// Finish building a [Query]. Call [Query.close()] after you're done with it
  /// to free resources.
  Query<T> build() {
    _applyCondition();

    try {
      return Query<T>._(_store, _cBuilder, _entity);
    } finally {
      _close();
    }
  }

  /// Configure how the results are ordered.
  /// Pass a combination of [Order] flags.
  QueryBuilder<T> order(QueryProperty p, {int flags = 0}) {
    _throwIfOtherEntity(p._entityId);
    checkObx(C.qb_order(_cBuilder, p._propertyId, flags));
    return this;
  }
}

/// Basic/linked query builder only has limited methods: link()
class _QueryBuilder<T> {
  final Store _store;
  final EntityDefinition<T> _entity;
  final Condition /*?*/ _queryCondition;
  Pointer<OBX_query_builder> /*?*/ _cBuilder;
  final _innerQBs = <_QueryBuilder>[];

  _QueryBuilder(
      this._store, this._entity, this._queryCondition, this._cBuilder) {
    checkObxPtr(_cBuilder, 'failed to create QueryBuilder');
  }

  _QueryBuilder._link(_QueryBuilder srcQB, this._queryCondition, this._cBuilder)
      : _store = srcQB._store,
        _entity = InternalStoreAccess.entityDef<T>(srcQB._store) {
    checkObxPtr(_cBuilder, 'failed to create QueryBuilder');
    _applyCondition();
  }

  void _close() {
    _innerQBs.forEach((iqb) => iqb._close());
    checkObx(C.qb_close(_cBuilder));
    _cBuilder = null;
  }

  void _throwExceptionIfNecessary() {
    if (C.qb_error_code(_cBuilder) != OBX_SUCCESS) {
      final msg = cString(C.qb_error_message(_cBuilder));
      throw ObjectBoxException(
          dartMsg: 'Query building failed', nativeMsg: msg);
    }
  }

  void _throwIfOtherEntity(int entityId) {
    if (entityId != _entity.model.id.id) {
      throw Exception(
          'Passed a property of another entity: $entityId instead of ${_entity.model.id.id}');
    }
  }

  void _applyCondition() {
    if (_queryCondition != null &&
        0 == _queryCondition /*!*/ ._apply(this, isRoot: true)) {
      _throwExceptionIfNecessary();
    }
  }

  _QueryBuilder<TargetEntityT> link<_, TargetEntityT>(
      QueryRelationProperty<_, TargetEntityT> rel,
      [Condition /*?*/ qc]) {
    _throwIfOtherEntity(rel._entityId);
    _innerQBs.add(_QueryBuilder<TargetEntityT>._link(
        this, qc, C.qb_link_property(_cBuilder, rel._propertyId)));
    return _innerQBs.last as _QueryBuilder<TargetEntityT>;
  }

  _QueryBuilder<SourceEntityT> backlink<SourceEntityT, _>(
      QueryRelationProperty<SourceEntityT, _> rel,
      [Condition /*?*/ qc]) {
    _throwIfOtherEntity(rel._targetEntityId);
    _innerQBs.add(_QueryBuilder<SourceEntityT>._link(this, qc,
        C.qb_backlink_property(_cBuilder, rel._entityId, rel._propertyId)));
    return _innerQBs.last as _QueryBuilder<SourceEntityT>;
  }

  _QueryBuilder<TargetEntityT> linkMany<_, TargetEntityT>(
      QueryRelationMany<_, TargetEntityT> rel,
      [Condition /*?*/ qc]) {
    _throwIfOtherEntity(rel._entityId);
    _innerQBs.add(_QueryBuilder<TargetEntityT>._link(
        this, qc, C.qb_link_standalone(_cBuilder, rel._relationId)));
    return _innerQBs.last as _QueryBuilder<TargetEntityT>;
  }

  _QueryBuilder<SourceEntityT> backlinkMany<SourceEntityT, _>(
      QueryRelationMany<SourceEntityT, _> rel,
      [Condition /*?*/ qc]) {
    _throwIfOtherEntity(rel._targetEntityId);
    _innerQBs.add(_QueryBuilder<SourceEntityT>._link(
        this, qc, C.qb_backlink_standalone(_cBuilder, rel._relationId)));
    return _innerQBs.last as _QueryBuilder<SourceEntityT>;
  }
}
