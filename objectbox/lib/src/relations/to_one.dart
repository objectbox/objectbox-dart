import 'package:meta/meta.dart';

import '../box.dart';
import '../modelinfo/entity_definition.dart';
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
  bool _attached = false;

  late final Store _store;

  late final Box<EntityT> _box;

  late final EntityDefinition<EntityT> _entity;

  _ToOneValue<EntityT> _value = _ToOneValue<EntityT>.none();

  /// Get target object. If it's the first access, this reads from DB.
  EntityT? get target {
    if (_value._state == _ToOneState.lazy) {
      _verifyAttached();
      final object = _box.get(_value._id);
      _value = (object == null)
          ? _ToOneValue<EntityT>.unresolvable(_value._id)
          : _ToOneValue<EntityT>.stored(_value._id, object);
    }
    return _value._object;
  }

  /// Set relation target object. Note: this does not store the change yet, use
  /// [Box.put()] on the containing (relation source) object.
  set target(EntityT? object) {
    if (object == null) {
      _value = _ToOneValue<EntityT>.none();
    } else if (_attached) {
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
      // If the target was previously set while not attached, the ID is unknown.
      // It's because we couldn't call _entity.getId() when _entity was null.
      // If, in the meantime, we have become attached, the ID can be resolved.
      if (_attached) {
        target = _value._object;
      } else {
        // Otherwise, we still can't access the ID so let's throw...
        _verifyAttached();
      }
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
        id == _getId(_value._object!)) {
      // Optimization for targetId being set from box.put(sourceObject)
      // after entity.setId(object, newID) was already called on the new target.
      _value = _ToOneValue<EntityT>.stored(id, _value._object!);
    } else if (_value._state != _ToOneState.unknown && id == _value._id) {
      return;
    } else {
      _value = _ToOneValue<EntityT>.lazy(id);
    }
  }

  /// Whether the relation field has a value stored. Otherwise it's null.
  bool get hasValue => _value._state != _ToOneState.none;

  /// Initialize the relation field, attaching it to the store.
  ///
  /// [Box.put()] calls this automatically. You only need to call this manually
  /// on new objects after you've set [target] and want to read [targetId],
  /// which is a very unusual operation because you've just assigned the
  /// [target] so you should know it's ID.
  void attach(Store store) {
    if (_attached) {
      if (_store != store) {
        throw ArgumentError.value(
            store, 'store', 'Relation already attached to a different store');
      }
      return;
    }
    _attached = true;
    _store = store;
    _box = store.box<EntityT>();
    _entity = InternalStoreAccess.entityDef<EntityT>(_store);
  }

  void _verifyAttached() {
    if (!_attached) {
      throw Exception('ToOne relation field not initialized. '
          'Make sure to call attach(store) before the first use.');
    }
  }

  int _getId(EntityT object) {
    _verifyAttached();
    return _entity.getId(object) ?? 0;
  }
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

/// Internal only.
@internal
class InternalToOneAccess {
  /// Get access of the relation's target box.
  static Box targetBox(ToOne toOne) {
    toOne._verifyAttached();
    return toOne._box;
  }
}
