import '../box.dart';
import '../modelinfo/entity_definition.dart';
import '../native/transaction.dart';
import '../native/weak_store.dart';
import '../store.dart';

/// Manages a to-one relation, an unidirectional link from a "source" entity to
/// a "target" entity. The target object is referenced by its ID, which is
/// persisted in the source object.
///
/// You can:
///   - set [target]=null or [targetId]=0 to remove the relation.
///   - set [target] to an object to set the relation.
///     Call [Box<SourceEntity>.put()] to persist the changes. If the target
///     object is a new one (its ID is 0), it will be also saved automatically.
///   - set [targetId] to an existing object's ID to set the relation.
///     Call [Box<SourceEntity>.put()] to persist the changes.
///
/// ```
/// @Entity()
/// class Order {
///   final customer = ToOne<Customer>();
///   ...
/// }
///
/// // Example 1: create a relation
/// final order = Order(...);
/// final customer = Customer();
/// order.customer.target = customer;
///
/// // Or you could create the target object in place:
/// // order.customer.target = Customer()
///
/// // attach() must be called when creating new instances. On objects (e.g.
/// // "orders" in this example) read with box.get() its done automatically.
/// order.customer.attach(store);
///
/// // saves both [customer] and [order] in the database
/// store.box<Order>().put(order);
///
///
/// // Example 2: remove a relation
///
/// order.customer.target = null
/// // ... or ...
/// order.customer.targetId = 0
/// ```
class ToOne<EntityT> {
  /// Store-related configuration attached to this.
  ///
  /// This is to have a single place to store attached configuration and to
  /// support sending this across isolates, which does not support sending a
  /// Store which contains a pointer.
  _ToOneStoreConfiguration<EntityT>? _storeConfiguration;

  _ToOneValue<EntityT> _value = _ToOneValue<EntityT>.none();

  /// Create a ToOne relationship.
  ///
  /// Normally, you don't assign the target in the constructor but rather use
  /// the `.target` setter. The option to assign in the constructor is useful
  /// to initialize objects from an external source, e.g. from JSON.
  ToOne({EntityT? target, int? targetId}) {
    if (targetId != null) {
      if (target != null) {
        // May be a user error... and we can't check if (target.id == targetId).
        throw ArgumentError(
            'Provide at most one specification of a ToOne relation target: '
            'either [target] or [targetId] argument');
      }
      this.targetId = targetId;
    } else if (target != null) {
      this.target = target;
    }
  }

  /// Get target object. If it's the first access, this reads from DB.
  EntityT? get target {
    if (_value._state == _ToOneState.lazy) {
      var storeAccess = _getStoreConfigOrThrow().getStoreAccess();
      final EntityT? object;
      try {
        object = storeAccess.box().get(_value._id);
      } finally {
        storeAccess.close();
      }
      _value = (object == null)
          ? _ToOneValue<EntityT>.unresolvable(_value._id)
          : _ToOneValue<EntityT>.stored(_value._id, object);
    }
    return _value._object;
  }

  /// Set relation target object. Note: this does not store the change yet, use
  /// [Box.put()] on the containing (relation source) object.
  set target(EntityT? object) {
    // If not attached, yet, avoid throwing and set the ID to unknown instead.
    // If the targetId getter is used later, it will call this to re-try
    // resolving the ID.
    if (object == null) {
      _value = _ToOneValue<EntityT>.none();
    } else if (_storeConfiguration != null) {
      final id = _getId(object);
      _value = (id == 0)
          ? _ToOneValue<EntityT>.unstored(object)
          : _ToOneValue<EntityT>.stored(id, object);
    } else {
      _value = _ToOneValue.unknown(object);
    }
  }

  /// Get ID of a relation target object.
  int get targetId {
    if (_value._state == _ToOneState.unknown) {
      // The target was set while this was not attached, so the target setter
      // set the ID as unknown.
      // If this is attached now, re-set the target so the target setter
      // resolves the ID. If still not attached, throw.
      _getStoreConfigOrThrow();
      target = _value._object;
    }
    return _value._id;
  }

  /// Set ID of a relation target object. Note: this does not store the change
  /// yet, use [Box.put()] on the containing (relation source) object.
  set targetId(int? id) {
    id ??= 0;
    if (id == 0) {
      _value = _ToOneValue<EntityT>.none();
    } else if (_value._state == _ToOneState.unstored &&
        id == _getId(_value._object as EntityT)) {
      // Optimization for targetId being set from box.put(sourceObject)
      // after entity.setId(object, newID) was already called on the new target.
      _value = _ToOneValue<EntityT>.stored(id, _value._object as EntityT);
    } else if (_value._state != _ToOneState.unknown && id == _value._id) {
      return;
    } else {
      _value = _ToOneValue<EntityT>.lazy(id);
    }
  }

  /// Whether the relation field has a value stored. Otherwise it's null.
  bool get hasValue => _value._state != _ToOneState.none;

  /// Initializes this relation, attaching it to the [store].
  ///
  /// Calling this is typically not necessary as e.g. for objects obtained via
  /// [Box.get] or put with [Box.put] this is called automatically.
  ///
  /// However, when creating a new instance of ToOne and setting [target], this
  /// must be called before accessing [targetId]. But in that case it is likely
  /// easier to get the target ID from the [target] object directly.
  void attach(Store store) {
    final storeConfiguration = _storeConfiguration;
    if (storeConfiguration != null) {
      if (storeConfiguration._storeConfiguration.id !=
          store.configuration().id) {
        throw ArgumentError.value(
            store, 'store', 'Relation already attached to a different store');
      }
      return;
    }
    _storeConfiguration = _ToOneStoreConfiguration(
        store.configuration(), InternalStoreAccess.entityDef<EntityT>(store));
  }

  _ToOneStoreConfiguration<EntityT> _getStoreConfigOrThrow() {
    final storeConfiguration = _storeConfiguration;
    if (storeConfiguration == null) {
      throw StateError("ToOne relation field not initialized. "
          "Make sure attach(store) is called before using this.");
    }
    return storeConfiguration;
  }

  int _getId(EntityT object) =>
      _getStoreConfigOrThrow().entity.getId(object) ?? 0;
}

enum _ToOneState { none, unstored, unknown, lazy, stored, unresolvable }

class _ToOneValue<EntityT> {
  final EntityT? _object;
  final int _id;
  final _ToOneState _state;

  /// NULL reference
  const _ToOneValue.none() : this._(_ToOneState.none, 0, null);

  /// Set by app developer, but not stored
  const _ToOneValue.unstored(EntityT object)
      : this._(_ToOneState.unstored, 0, object);

  /// Set by app developer before attach() was called - maybe new or existing
  const _ToOneValue.unknown(EntityT object)
      : this._(_ToOneState.unknown, 0, object);

  /// Initial state before attempting a lazy load
  const _ToOneValue.lazy(int id) : this._(_ToOneState.lazy, id, null);

  /// Known reference established in the database
  const _ToOneValue.stored(int id, EntityT object)
      : this._(_ToOneState.stored, id, object);

  /// ID set but not present in database
  const _ToOneValue.unresolvable(int id)
      : this._(_ToOneState.unresolvable, id, null);

  const _ToOneValue._(this._state, this._id, this._object);
}

/// This hides away methods from the public API
/// (this is not marked as show in objectbox.dart)
/// while remaining accessible by other libraries in this package.
extension ToOneInternal<EntityT> on ToOne<EntityT> {
  /// Puts the [target] if it is new.
  void applyToDb(PutMode mode, Transaction tx) {
    // Put if target object is new.
    if (targetId == 0) {
      final storeAccess = _getStoreConfigOrThrow().getStoreAccess();
      try {
        targetId = InternalBoxAccess.put(storeAccess.box(), target, mode, tx);
      } finally {
        storeAccess.close();
      }
    }
  }
}

/// This stores the target entity type with the store configuration.
class _ToOneStoreConfiguration<EntityT> {
  final StoreConfiguration _storeConfiguration;
  final EntityDefinition<EntityT> entity;

  _ToOneStoreConfiguration(this._storeConfiguration, this.entity);

  _ToOneStoreAccess<EntityT> getStoreAccess() => _ToOneStoreAccess(this);
}

// TODO Add base class with _ToManyStoreAccess?
/// This provides temporary access to a store given a store configuration.
class _ToOneStoreAccess<EntityT> {
  final _ToOneStoreConfiguration<EntityT> configuration;
  Store _store;

  factory _ToOneStoreAccess(_ToOneStoreConfiguration<EntityT> configuration) {
    final weakStore = WeakStore.get(configuration._storeConfiguration);
    final store = weakStore.lock();
    return _ToOneStoreAccess._fromFactory(configuration, store);
  }

  _ToOneStoreAccess._fromFactory(this.configuration, this._store);

  Box<EntityT> box() => _store.box<EntityT>();

  void close() {
    _store.close();
  }
}
