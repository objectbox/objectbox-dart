part of query;

/// Query builder allows creating reusable queries.
class QueryBuilder<T> extends _QueryBuilder<T> {
  /// Start creating a query.
  QueryBuilder(Store store, EntityDefinition<T> entity, Condition<T>? qc)
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

  /// Finish building a [Query] creating a [Stream] that issues events whenever
  /// the queried entity changes. The streamed query is persisted between stream
  /// events and can be used even after the subscription is cancelled.
  ///
  /// If you pass TRUE as the [triggerImmediately] argument, a single stream
  /// event will be sent immediately after subscribing. You can use this to get
  /// access to the query object before any data changes.
  Stream<Query<T>> watch({bool triggerImmediately = false}) {
    final queriedEntities = HashSet<Type>();
    _fillQueriedEntities(queriedEntities);
    final query = build();
    late StreamSubscription<void> subscription;
    late StreamController<Query<T>> controller;
    final subscribe = () {
      subscription = _store.entityChanges.listen((List<Type> entityTypes) {
        if (entityTypes.any(queriedEntities.contains)) {
          controller.add(query);
        }
      });
    };
    controller = StreamController<Query<T>>(
        onListen: subscribe,
        onResume: subscribe,
        onPause: () => subscription.pause(),
        onCancel: () => subscription.cancel());
    if (triggerImmediately) controller.add(query);
    return controller.stream;
  }

  /// Configure how the results are ordered.
  /// Pass a combination of [Order] flags.
  void order<_>(QueryProperty<T, _> p, {int flags = 0}) =>
      checkObx(C.qb_order(_cBuilder, p._model.id.id, flags));
}

/// Basic/linked query builder only has limited methods: link()
class _QueryBuilder<T> {
  final Store _store;
  final EntityDefinition<T> _entity;
  final Condition<T>? _queryCondition;
  final Pointer<OBX_query_builder> _cBuilder;
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
    srcQB._innerQBs.add(this);
  }

  void _fillQueriedEntities(Set<Type> outEntities) {
    outEntities.add(T);
    _innerQBs.forEach((qb) => qb._fillQueriedEntities(outEntities));
  }

  void _close() {
    _innerQBs.forEach((iqb) => iqb._close());
    checkObx(C.qb_close(_cBuilder));
  }

  @pragma('vm:prefer-inline')
  void _throwExceptionIfNecessary() {
    final code = C.qb_error_code(_cBuilder);
    if (code != OBX_SUCCESS) {
      ObjectBoxNativeError(code, dartStringFromC(C.qb_error_message(_cBuilder)),
              'Query building failed')
          .throwMapped();
    }
  }

  @pragma('vm:prefer-inline')
  void _applyCondition() => _queryCondition?._applyFull(this, isRoot: true);

  _QueryBuilder<TargetEntityT> link<TargetEntityT>(
          QueryRelationToOne<T, TargetEntityT> rel,
          [Condition<TargetEntityT>? qc]) =>
      _QueryBuilder<TargetEntityT>._link(
          this, qc, C.qb_link_property(_cBuilder, rel._model.id.id));

  _QueryBuilder<SourceEntityT> backlink<SourceEntityT>(
          QueryRelationToOne<SourceEntityT, T> rel,
          [Condition<SourceEntityT>? qc]) =>
      _QueryBuilder<SourceEntityT>._link(
          this,
          qc,
          C.qb_backlink_property(
              _cBuilder,
              InternalStoreAccess.entityDef<SourceEntityT>(_store).model.id.id,
              rel._model.id.id));

  _QueryBuilder<TargetEntityT> linkMany<TargetEntityT>(
          QueryRelationToMany<T, TargetEntityT> rel,
          [Condition<TargetEntityT>? qc]) =>
      _QueryBuilder<TargetEntityT>._link(
          this, qc, C.qb_link_standalone(_cBuilder, rel._model.id.id));

  _QueryBuilder<SourceEntityT> backlinkMany<SourceEntityT>(
          QueryRelationToMany<SourceEntityT, T> rel,
          [Condition<SourceEntityT>? qc]) =>
      _QueryBuilder<SourceEntityT>._link(
          this, qc, C.qb_backlink_standalone(_cBuilder, rel._model.id.id));
}
