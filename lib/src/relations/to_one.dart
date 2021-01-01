import '../box.dart';
import '../store.dart';

/// Manages a to-one relation: resolves the target object, keeps the target Id in sync, etc.
/// A to-relation is unidirectional: it points from the source entity to the target entity.
/// The target is referenced by its ID, which is persisted in the source entity.
///
/// TODO:
/// If there is a [ToMany] relation linking back to this to-one relation
/// [@Backlink()], the [ToMany] object will not be notified/updated about
/// changes persisted here. Call [ToMany.reset()] to update when next accessed.
class ToOne<EntityT> {
  /*late final*/ Box<EntityT> _box;

  _ToOneValue<EntityT> _value = _ToOneValue<EntityT>.none();

  EntityT /*?*/ get target {
    if (_value._state == _ToOneState.lazy) {
      final object = _box /*!*/ .get(_value._id);
      _value = (object == null)
          ? _ToOneValue<EntityT>.unresolvable(_value._id)
          : _ToOneValue<EntityT>.stored(_value._id, object);
    }
    return _value._object;
  }

  set target(EntityT /*?*/ object) {
    if (object == null) {
      _value = _ToOneValue<EntityT>.none();
    } else {
      // TODO id getter - needed when the field isn't called `id`.
      //      Adding [EntityDefinition.getId()] would probably make most sense.
      int id = (object as dynamic).id;
      _value = (id == 0)
          ? _ToOneValue<EntityT>.unstored(object)
          : _ToOneValue<EntityT>.stored(id, object);
    }
  }

  int get targetId => _value._id;

  set targetId(int /*?*/ id) {
    id ??= 0;
    if (id == _value._id) return;
    _value =
        (id == 0) ? _ToOneValue<EntityT>.none() : _ToOneValue<EntityT>.lazy(id);
  }

  bool get hasValue => _value._state != _ToOneState.none;

  void attach(Store store) {
    _box = Box<EntityT>(store);
  }
}

enum _ToOneState { none, unstored, lazy, stored, unresolvable }

class _ToOneValue<EntityT> {
  final EntityT /*?*/ _object;
  final int _id;
  final _ToOneState _state;

  /// NULL reference
  const _ToOneValue.none() : this._(_ToOneState.none, 0, null);

  /// Set by app developer, but not stored
  const _ToOneValue.unstored(EntityT object)
      : this._(_ToOneState.unstored, 0, object);

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
