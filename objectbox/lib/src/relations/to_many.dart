import 'dart:collection';

import 'package:meta/meta.dart';

import '../box.dart';
import '../modelinfo/entity_definition.dart';
import '../store.dart';
import '../transaction.dart';
import 'info.dart';

/// ToManyRelationProvider interface to use ToMany or ToManyProxy in same context
abstract class ToManyRelationProvider<EntityT> {
  /// Provider must implements relation getter
  ToMany<EntityT> get relation;

  /// Save changes made to this ToMany relation to the database. Alternatively,
  /// you can call box.put(object) or box.putImmutable, its relations are automatically saved.
  ///
  /// If this collection contains new objects (with zero IDs),  applyToDb()
  /// will put them on-the-fly. For this to work the source object (the object
  /// owing this ToMany) must be already stored because its ID is required.
  void applyToDb({
    PutMode mode = PutMode.put,
    Transaction? tx,
  });
}

/// Manages a to-many relation, an unidirectional link from a "source" entity to
/// multiple objects of a "target" entity.
///
/// You can:
///   - [add()] new objects to the relation.
///   - [removeAt()] target objects from the relation at a specific list index.
///   - [remove(id:)] target objects from the relation by an ID.
///
/// ```
/// class Student {
///   final teachers = ToMany<Teacher>();
///   ...
/// }
///
/// // Example 1: create a relation
/// final teacher1 = Teacher();
/// final teacher2 = Teacher();
///
/// final student1 = Student();
/// student1.teachers.add(teacher1);
/// student1.teachers.add(teacher2);
///
/// final student2 = Student();
/// student2.teachers.add(teacher2);
///
/// // saves students as well as teachers in the database
/// store.box<Student>().putMany([student1, student2]);
///
///
/// // Example 2: remove a relation
///
/// student.teachers.removeAt(index)
/// student.teachers.applyToDb(); // or store.box<Student>().put(student);
/// ```
class ToMany<EntityT> extends Object
    with ListMixin<EntityT>
    implements ToManyRelationProvider<EntityT> {
  bool _attached = false;

  late final Store _store;

  /// Standard direction: target box; backlinks: source box.
  late final Box<EntityT> _box;

  /// Standard direction: source box; backlinks: target box.
  late final Box _otherBox;

  late final EntityDefinition<EntityT> _entity;

  RelInfo? _rel;

  List<EntityT>? __items;
  final _counts = <EntityT, int>{};
  final _addedBeforeLoad = <EntityT>[];

  /// Create a ToMany relationship.
  ///
  /// Normally, you don't assign items in the constructor but rather use this
  /// class as a lazy-loaded/saved list. The option to assign in the constructor
  /// is useful to initialize objects from an external source, e.g. from JSON.
  /// Setting the items in the constructor bypasses the lazy loading, ignoring
  /// any relations that are currently stored in the DB for the source object.
  ToMany({List<EntityT>? items}) {
    if (items != null) {
      __items = items;
      items.forEach(_track);
    }
  }

  @override
  int get length => _items.length;

  @override
  set length(int newLength) {
    if (newLength < _items.length) {
      _items
          .getRange(newLength, _items.length)
          .forEach((EntityT element) => _track(element, -1));
    }
    _items.length = newLength;
  }

  @override
  EntityT operator [](int index) => _items[index];

  @override
  void operator []=(int index, EntityT element) {
    final items = _items;
    if (0 > index || index >= items.length) {
      throw RangeError.index(index, this);
    }
    if (index < items.length) {
      if (items[index] == element) return;
      _track(items[index], -1);
    }
    items[index] = element;
    _track(element, 1);
  }

  @override
  void add(EntityT element) {
    ArgumentError.checkNotNull(element, 'element');
    _track(element, 1);
    if (!_itemsLoaded) {
      // We don't need to load old data from DB to add new items.
      _addedBeforeLoad.add(element);
    } else {
      _items.add(element);
    }
  }

  @override
  void addAll(Iterable<EntityT> iterable) {
    iterable.forEach(_track);
    if (!_itemsLoaded) {
      // We don't need to load old data from DB to add new items.
      _addedBeforeLoad.addAll(iterable);
    } else {
      _items.addAll(iterable);
    }
  }

  // note: to override, arg must be "Object", same as in the base class.
  @override
  bool remove(Object? element) {
    if (!_items.remove(element)) return false;
    if (element != null) _track(element as EntityT, -1);
    return true;
  }

  /// "add":    increment = 1
  /// "remove": increment = -1
  void _track(EntityT object, [int increment = 1]) {
    if (_counts.containsKey(object)) {
      _counts[object] = _counts[object]! + increment;
    } else {
      _counts[object] = increment;
    }
  }

  @override
  List<EntityT> toList({bool growable = true}) =>
      _items.toList(growable: growable);

  /// True if there are any changes not yet saved in DB.
  bool get _hasPendingDbChanges => _counts.values.any((c) => c != 0);

  void _updateObjectInItems(EntityT from, EntityT to) {
    if (from == to || !_itemsLoaded) {
      return;
    }

    final idx = _items.indexOf(from);
    if (idx > -1) {
      _items[idx] = to;
    }
  }

  /// Save changes made to this ToMany relation to the database. Alternatively,
  /// you can call box.put(object), its relations are automatically saved.
  ///
  /// If this collection contains new objects (with zero IDs),  applyToDb()
  /// will put them on-the-fly. For this to work the source object (the object
  /// owing this ToMany) must be already stored because its ID is required.
  @override
  void applyToDb({
    PutMode mode = PutMode.put,
    Transaction? tx,
  }) {
    if (!_hasPendingDbChanges) return;
    _verifyAttached();

    if (_rel == null) {
      throw StateError("Relation info not initialized, can't applyToDb()");
    }

    if (_rel!.objectId == 0) {
      // This shouldn't happen but let's be a little paranoid.
      throw StateError(
          "Can't store relation info for the target object with zero ID");
    }

    final ownedTx = tx == null;
    tx ??= Transaction(_store, TxMode.write);
    try {
      _counts.forEach((EntityT object, count) {
        if (count == 0) return;
        final add = count > 0; // otherwise: remove
        var id = _entity.getId(object) ?? 0;

        switch (_rel!.type) {
          case RelType.toMany:
            if (add) {
              if (id == 0) {
                final result = InternalBoxAccess.put(_box, object, mode, tx);
                _updateObjectInItems(object, result.object);
                id = result.id;
              }
              InternalBoxAccess.relPut(_otherBox, _rel!.id, _rel!.objectId, id);
            } else {
              if (id == 0) return;
              InternalBoxAccess.relRemove(
                  _otherBox, _rel!.id, _rel!.objectId, id);
            }
            break;
          case RelType.toOneBacklink:
            final srcField = _rel!.toOneSourceField(object);
            srcField.targetId = add ? _rel!.objectId : null;

            final result = InternalBoxAccess.putClearCache(_box, object, mode);
            _updateObjectInItems(object, result);

            break;
          case RelType.toManyBacklink:
            if (add) {
              if (id == 0) {
                final result = InternalBoxAccess.put(_box, object, mode, tx);
                _updateObjectInItems(object, result.object);
                id = result.id;
              }
              InternalBoxAccess.relPut(_box, _rel!.id, id, _rel!.objectId);
            } else {
              if (id == 0) return;
              InternalBoxAccess.relRemove(_box, _rel!.id, id, _rel!.objectId);
            }
            break;
          default:
            throw UnimplementedError();
        }
      });
      if (ownedTx) tx.successAndClose();
    } catch (ex) {
      // Is a no-op if successAndClose did throw.
      if (ownedTx) tx.abortAndClose();
      rethrow;
    }

    _counts.clear();
    _addedBeforeLoad.clear();
  }

  void _setRelInfo(Store store, RelInfo rel, Box otherBox) {
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
    _rel = rel;
    _otherBox = otherBox;
  }

  List<EntityT> get _items => __items ??= _loadItems();
  bool get _itemsLoaded => __items != null;

  List<EntityT> _loadItems() {
    if (_rel == null) {
      // Null _rel means this relation is used on a new (not stored) object.
      // Therefore, we're sure there are no stored items yet.
      __items = [];
    } else {
      _verifyAttached();
      __items = InternalBoxAccess.getRelated(_box, _rel!);
    }
    if (_addedBeforeLoad.isNotEmpty) {
      __items!.addAll(_addedBeforeLoad);
      _addedBeforeLoad.clear();
    }
    return __items!;
  }

  void _verifyAttached() {
    if (!_attached) {
      throw StateError('ToMany relation field not initialized. '
          "Don't call applyToDb() on new objects, use box.put() instead.");
    }
  }

  /// [ToManyRelationProvider] interface implementtation
  @override
  ToMany<EntityT> get relation => this;
}

/// Proxy ToMany relation between immutable entities
class ToManyProxy<EntityT> implements ToManyRelationProvider<EntityT> {
  late ToMany<EntityT> _sharedRelation;

  /// [ToManyRelationProvider] interface implementtation
  @override
  ToMany<EntityT> get relation => _sharedRelation;

  /// [ToManyRelationProvider] interface implementtation
  @override
  void applyToDb({PutMode mode = PutMode.put, Transaction? tx}) {
    relation.applyToDb(mode: mode, tx: tx);
  }

  /// Clone relation link from another proxy
  void cloneFrom(ToManyRelationProvider<EntityT> other) {
    _sharedRelation = other.relation;
  }

  /// [ListMixin] proxy to underlying [ToMany] relation
  int get length => relation.length;

  /// [ListMixin] proxy to underlying [ToMany] relation
  EntityT operator [](int index) => relation[index];

  /// [ListMixin] proxy to underlying [ToMany] relation
  void operator []=(int index, EntityT element) {
    relation[index] = element;
  }

  /// [ListMixin] proxy to underlying [ToMany] relation
  void add(EntityT element) {
    relation.add(element);
  }

  /// [ListMixin] proxy to underlying [ToMany] relation
  void addAll(Iterable<EntityT> iterable) {
    relation.addAll(iterable);
  }

  /// [ListMixin] proxy to underlying [ToMany] relation
  Iterable<T> map<T>(T Function(EntityT) f) => relation.map(f);

  /// [ListMixin] proxy to underlying [ToMany] relation
  bool remove(Object? element) => relation.remove(element);

  /// [ListMixin] proxy to underlying [ToMany] relation
  void removeWhere(bool Function(EntityT) test) {
    relation.removeWhere(test);
  }

  /// [ListMixin] proxy to underlying [ToMany] relation
  void clear() {
    relation.clear();
  }

  /// Create a ToManyProxy for shared ToMany relationship between immutable entities.
  ///
  /// Normally, you don't assign items in the constructor but rather use this
  /// class as a lazy-loaded/saved list. The option to assign in the constructor
  /// is useful to initialize objects from an external source, e.g. from JSON.
  /// Setting the items in the constructor bypasses the lazy loading, ignoring
  /// any relations that are currently stored in the DB for the source object.
  ToManyProxy({List<EntityT>? items}) {
    _sharedRelation = ToMany(items: items);
  }
}

/// Internal only.
class InternalToManyAccess {
  /// Check whether the relation has any unsaved changes.
  @internal
  static bool hasPendingDbChanges(ToMany toMany) => toMany._hasPendingDbChanges;

  /// Set relation info.
  static void setRelInfo(ToManyRelationProvider toMany, Store store,
          RelInfo rel, Box srcBox) =>
      toMany.relation._setRelInfo(store, rel, srcBox);
}

/// Internal only.
@internal
@visibleForTesting
class InternalToManyTestAccess<EntityT> {
  final ToManyRelationProvider<EntityT> _rel;

  /// Used in tests.
  bool get itemsLoaded => _rel.relation._itemsLoaded;

  /// Used in tests.
  List<EntityT> get items => _rel.relation._items;

  /// Used in tests.
  Set<EntityT> get added {
    final result = <EntityT>{};
    _rel.relation._counts.forEach((EntityT object, count) {
      if (count > 0) result.add(object);
    });
    return result;
  }

  /// Used in tests.
  Set<EntityT> get removed {
    final result = <EntityT>{};
    _rel.relation._counts.forEach((EntityT object, count) {
      if (count < 0) result.add(object);
    });
    return result;
  }

  /// Used in tests.
  InternalToManyTestAccess(this._rel);
}
