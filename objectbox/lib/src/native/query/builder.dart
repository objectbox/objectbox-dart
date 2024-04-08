part of 'query.dart';

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

  /// Builds the [Query] and creates a [single-subscription](https://dart.dev/tutorials/language/streams#two-kinds-of-streams)
  /// [Stream] that sends the query whenever there are changes to the boxes of
  /// the queried entities.
  ///
  /// Use [triggerImmediately] to send an event immediately after subscribing,
  /// even before an actual change.
  ///
  /// A common use case is to get a list of the latest results for a UI widget:
  /// ```
  /// // Map to a stream of results, immediately get current results.
  /// final Stream<List<Entity>> listStream = box.query()
  ///     .watch(triggerImmediately: true)
  ///     .map((query) => query.find());
  /// ```
  ///
  /// However, this method allows to do whatever needed with the returned query:
  /// ```
  /// box.query().watch().listen((query) {
  ///   // Do something with query, e.g. find or count.
  /// });
  /// ```
  ///
  /// The stream is a single-subscription stream, so can only be listened to once.
  /// The query returned by the stream is persisted between events and can be
  /// used even after the subscription is cancelled (the query is not explicitly
  /// closed).
  Stream<Query<T>> watch({bool triggerImmediately = false}) {
    final queriedEntities = HashSet<Type>();
    _fillQueriedEntities(queriedEntities);
    final query = build();
    late StreamSubscription<void> subscription;
    late StreamController<Query<T>> controller;

    subscribe() {
      subscription = _store.entityChanges.listen((List<Type> entityTypes) {
        if (entityTypes.any(queriedEntities.contains)) {
          controller.add(query);
        }
      });
    }

    // Note: this can not be a broadcast StreamController (to allow
    // re-subscribing or multiple subscribers) as it would not be
    // possible to implement the send on listen (triggerImmediately)
    // functionality (onListen is only called for the first subscriber,
    // also does not allow to send an event within).
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
  ///
  /// For example:
  /// ```
  /// final query = box
  ///     .query()
  ///     .order(Person_.name, flags: Order.ascending)
  ///     .build();
  /// ```
  QueryBuilder<T> order<D>(QueryProperty<T, D> p, {int flags = 0}) {
    checkObx(C.qb_order(_cBuilder, p._model.id.id, flags));
    // Using Dart's cascade operator does not allow for nice chaining with
    // build(), so explicitly return this for a more fluent interface.
    // ignore: avoid_returning_this
    return this;
  }
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
    for (var qb in _innerQBs) {
      qb._fillQueriedEntities(outEntities);
    }
  }

  void _close() {
    for (var iqb in _innerQBs) {
      iqb._close();
    }
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

  /// Based on a to-one relation [rel] of this entity, creates a link to another
  /// entity, for which conditions using the returned builder can be described.
  ///
  /// ```
  /// final builder = orderBox.query(Order_.name.equals('Misc'));
  /// builder.link(Order_.customer, Customer_.name.equals('Jane'));
  /// final query = builder.build();
  /// ```
  _QueryBuilder<TargetEntityT> link<TargetEntityT>(
          QueryRelationToOne<T, TargetEntityT> rel,
          [Condition<TargetEntityT>? qc]) =>
      _QueryBuilder<TargetEntityT>._link(
          this, qc, C.qb_link_property(_cBuilder, rel._model.id.id));

  /// Like [link], but where the to-one relation is defined in the other object.
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

  /// Based on a to-many relation [rel] of this entity, creates a link to another
  /// entity, for which conditions using the returned builder can be described.
  ///
  /// ```
  /// final builder = personBox.query(Person_.name.equals('Elmo'));
  /// builder.linkMany(Person_.addresses, Address_.street.equals('Sesame Street'));
  /// final query = builder.build();
  /// ```
  _QueryBuilder<TargetEntityT> linkMany<TargetEntityT>(
          QueryRelationToMany<T, TargetEntityT> rel,
          [Condition<TargetEntityT>? qc]) =>
      _QueryBuilder<TargetEntityT>._link(
          this, qc, C.qb_link_standalone(_cBuilder, rel._model.id.id));

  /// Like [linkMany], but where the to-many relation is defined in the other object.
  _QueryBuilder<SourceEntityT> backlinkMany<SourceEntityT>(
          QueryRelationToMany<SourceEntityT, T> rel,
          [Condition<SourceEntityT>? qc]) =>
      _QueryBuilder<SourceEntityT>._link(
          this, qc, C.qb_backlink_standalone(_cBuilder, rel._model.id.id));
}
