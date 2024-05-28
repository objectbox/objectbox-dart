import '../annotations.dart';
import '../box.dart';
import '../modelinfo/entity_definition.dart';
import '../native/transaction.dart';
import '../store.dart';

/// A to-one relation of an entity that references one object of a "target" entity [EntityT].
///
/// Example:
/// ```
/// @Entity()
/// class Order {
///   final customer = ToOne<Customer>();
/// }
/// ```
///
/// Uses lazy initialization.
/// The [target] object is only read from the database when it is first accessed.
///
/// Common usage:
///   - set the [target] object to create a relation.
///     When the object with the ToOne is put, if the target object is new (its ID is 0), it will be put as well.
///     Otherwise, only the target ID in the database is updated.
///   - set the [targetId] of the target object to create a relation.
///   - set [target] to `null` or [targetId] to `0` to remove the relation.
///
/// Then, to persist the changes [Box.put] the object with the ToOne.
///
/// ```
/// // Example 1: create a relation
/// order.customer.target = customer;
/// // or order.customer.targetId = customerId;
/// store.box<Order>().put(order);
///
/// // Example 2: remove the relation
/// order.customer.target = null
/// // or order.customer.targetId = 0
/// store.box<Order>().put(order);
/// ```
///
/// The target object is referenced by its ID.
/// This [targetId] is persisted as part of the object with the ToOne in a special
/// property created for each ToOne (named like "customerId").
///
/// To get all objects with a ToOne that reference a target object, see [Backlink].
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

  /// Returns the target object or `null` if there is none.
  ///
  /// [ToOne] uses lazy initialization, so on first access this will read the target object from the database.
  EntityT? get target {
    if (_value._state == _ToOneState.lazy) {
      final configuration = _getStoreConfigOrThrow();
      var store =
          StoreInternal.attachByConfiguration(configuration.storeConfiguration);
      final EntityT? object;
      try {
        object = configuration.box(store).get(_value._id);
      } finally {
        store.close();
      }
      _value = (object == null)
          ? _ToOneValue<EntityT>.unresolvable(_value._id)
          : _ToOneValue<EntityT>.stored(_value._id, object);
    }
    return _value._object;
  }

  /// Prepares to set the target object of this relation.
  /// Pass `null` to remove an existing one.
  ///
  /// To apply changes, put the object with the ToOne.
  /// For important details, see the notes about relations of [Box.put].
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

  /// Prepares to set the target of this relation to the object with the given [id].
  /// Pass `0` to remove an existing one.
  ///
  /// To apply changes, put the object with the ToOne.
  /// For important details, see the notes about relations of [Box.put].
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
    final configuration = _storeConfiguration;
    if (configuration != null) {
      if (configuration.storeConfiguration.id != store.configuration().id) {
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
  void applyToDb(Store store, PutMode mode, Transaction tx) {
    if (!hasValue) return;
    // Attach so can get box below.
    attach(store);
    // Put if target object is new.
    if (targetId == 0) {
      // Note: would call store.box<EntityT>() here directly, but callers might
      // use dynamic as EntityT. So get box via embedded config class that
      // definitely has a type for EntityT.
      targetId = InternalBoxAccess.put(
          _getStoreConfigOrThrow().box(store), target, mode, tx);
    }
  }
}

/// This stores the target entity type with the store configuration.
class _ToOneStoreConfiguration<EntityT> {
  final StoreConfiguration storeConfiguration;
  final EntityDefinition<EntityT> entity;

  _ToOneStoreConfiguration(this.storeConfiguration, this.entity);

  /// Get box for EntityT.
  Box<EntityT> box(Store store) => store.box<EntityT>();
}
