import 'dart:collection';
import 'dart:ffi';

import 'package:meta/meta.dart';
import 'package:objectbox/src/bindings/bindings.dart';
import 'package:objectbox/src/bindings/helpers.dart';

import 'info.dart';
import '../box.dart';
import '../modelinfo/entity_definition.dart';
import '../store.dart';
import '../transaction.dart';

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
class ToMany<EntityT> extends Object with ListMixin<EntityT> {
  /*late final*/ Store _store;

  /// Standard direction: target box; backlinks: source box.
  /*late final*/
  Box<EntityT> _box;

  /// Standard direction: source box; backlinks: target box.
  /*late final*/
  Box _otherBox;

  /*late final*/
  EntityDefinition<EntityT> _entity;

  RelInfo _rel;

  List<EntityT> /*?*/ __items;
  final _counts = <EntityT, int>{};
  final _addedBeforeLoad = <EntityT>[];

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
    if (__items == null) {
      // We don't need to load old data from DB to add new items.
      _addedBeforeLoad.add(element);
    } else {
      _items.add(element);
    }
  }

  @override
  void addAll(Iterable<EntityT> iterable) {
    iterable.forEach((element) {
      ArgumentError.checkNotNull(element, 'iterable element');
      _track(element, 1);
    });
    if (__items == null) {
      // We don't need to load old data from DB to add new items.
      _addedBeforeLoad.addAll(iterable);
    } else {
      _items.addAll(iterable);
    }
  }

  // note: to override, arg must be "Object", same as in the base class.
  @override
  bool remove(Object /*?*/ element) {
    if (!_items.remove(element)) return false;
    if (element != null) _track(element as EntityT, -1);
    return true;
  }

  /// "add":    increment = 1
  /// "remove": increment = -1
  void _track(EntityT object, int increment) {
    if (_counts.containsKey(object)) {
      _counts[object] += increment;
    } else {
      _counts[object] = increment;
    }
  }

  @override
  List<EntityT> toList({bool growable = true}) =>
      _items.toList(growable: growable);

  /// True if there are any changes not yet saved in DB.
  bool get _hasPendingDbChanges => _counts.values.any((c) => c != 0);

  /// Save changes made to this ToMany relation to the database. Alternatively,
  /// you can call box.put(object), its relations are automatically saved.
  ///
  /// If this collection contains new objects (with zero IDs),  applyToDb()
  /// will put them on-the-fly. For this to work the source object (the object
  /// owing this ToMany) must be already stored because its ID is required.
  void applyToDb({PutMode mode = PutMode.Put, Transaction tx}) {
    if (!_hasPendingDbChanges) return;
    _verifyAttached();

    if (_rel == null) {
      throw StateError("Relation info not initialized, can't applyToDb()");
    }

    if (_rel.objectId == 0) {
      // This shouldn't happen but let's be a little paranoid.
      throw Exception(
          "Can't store relation info for the target object with zero ID");
    }

    final ownedTx = tx == null;
    tx ??= Transaction(_store, TxMode.Write);
    try {
      _counts.forEach((EntityT object, count) {
        if (count == 0) return;
        final add = count > 0; // otherwise: remove
        var id = _entity.getId(object) ?? 0;

        switch (_rel.type) {
          case RelType.toMany:
            if (add) {
              if (id == 0) id = _box.put(object, mode: mode);
              checkObx(
                  C.box_rel_put(_otherBox.ptr, _rel.id, _rel.objectId, id));
            } else {
              if (id == 0) return;
              checkObx(
                  C.box_rel_remove(_otherBox.ptr, _rel.id, _rel.objectId, id));
            }
            break;
          case RelType.toOneBacklink:
            final srcField = _rel.toOneSourceField(object);
            srcField.targetId = add ? _rel.objectId : null;
            _box.put(object, mode: mode);
            break;
          case RelType.toManyBacklink:
            if (add) {
              if (id == 0) id = _box.put(object, mode: mode);
              checkObx(C.box_rel_put(_box.ptr, _rel.id, id, _rel.objectId));
            } else {
              if (id == 0) return;
              checkObx(C.box_rel_remove(_box.ptr, _rel.id, id, _rel.objectId));
            }
            break;
          default:
            throw UnimplementedError();
        }
      });
      if (ownedTx) tx.markSuccessful(true);
    } finally {
      if (ownedTx) tx.close();
    }

    _counts.clear();
  }

  void _setRelInfo(Store store, RelInfo rel, Box otherBox) {
    _store = store;
    _box = store.box<EntityT>();
    _entity = InternalStoreAccess.entityDef<EntityT>(_store);
    _rel = rel;
    _otherBox = otherBox;
  }

  List<EntityT> get _items => __items ??= _loadItems();

  List<EntityT> _loadItems() {
    if (_rel == null) {
      // Null _rel means this relation is used on a new (not stored) object.
      // Therefore, we're sure there are no stored items yet.
      __items = [];
    } else {
      _verifyAttached();
      switch (_rel.type) {
        case RelType.toMany:
          __items = _getMany(
              () => C.box_rel_get_ids(_box.ptr, _rel.id, _rel.objectId));
          break;
        case RelType.toOneBacklink:
          __items = _getMany(
              () => C.box_get_backlink_ids(_box.ptr, _rel.id, _rel.objectId));
          break;
        case RelType.toManyBacklink:
          __items = _getMany(() =>
              C.box_rel_get_backlink_ids(_box.ptr, _rel.id, _rel.objectId));
          break;
        default:
          throw UnimplementedError();
      }
    }
    if (_addedBeforeLoad.isNotEmpty) {
      __items.addAll(_addedBeforeLoad);
      _addedBeforeLoad.clear();
    }
    return __items;
  }

  void _verifyAttached() {
    if (_store == null) {
      throw Exception('ToMany relation field not initialized. '
          "Don't call applyToDb() on new objects, use box.put() instead.");
    }
  }

  /// Similar to box.getMany() but loads the OBX_id_array and reads objects
  /// in a single Transaction, ensuring consistency. And it's a little more
  /// efficient for not unpacking the id array to a dart list.
  List<EntityT> _getMany(Pointer<OBX_id_array> Function() cIdsGetterFn) {
    final tx = Transaction(_store, TxMode.Read);
    try {
      final result = <EntityT>[];
      final cIdsPtr = checkObxPtr(cIdsGetterFn());
      try {
        final cIds = cIdsPtr.ref;
        if (cIds.count > 0) {
          final cursor = tx.cursor(_entity);
          for (var i = 0; i < cIds.count; i++) {
            final code = C.cursor_get(
                cursor.ptr, cIds.ids[i], cursor.dataPtrPtr, cursor.sizePtr);
            if (code != OBX_NOT_FOUND) {
              checkObx(code);
              result.add(_entity.objectFromFB(_store, cursor.readData));
            }
          }
        }
      } finally {
        C.id_array_free(cIdsPtr);
      }
      return result;
    } finally {
      tx.close();
    }
  }
}

class InternalToManyAccess {
  // TODO enable annotation once meta:1.3.0 is out
  // @internal
  static bool hasPendingDbChanges(ToMany toMany) => toMany._hasPendingDbChanges;

  static void setRelInfo(ToMany toMany, Store store, RelInfo rel, Box srcBox) =>
      toMany._setRelInfo(store, rel, srcBox);
}

// TODO enable annotation once meta:1.3.0 is out
// @internal
@visibleForTesting
class InternalToManyTestAccess<EntityT> {
  final ToMany<EntityT> _rel;

  bool get itemsLoaded => _rel.__items != null;

  List<EntityT> get items => _rel._items;

  Set<EntityT> get added {
    final result = <EntityT>{};
    _rel._counts.forEach((EntityT object, count) {
      if (count > 0) result.add(object);
    });
    return result;
  }

  Set<EntityT> get removed {
    final result = <EntityT>{};
    _rel._counts.forEach((EntityT object, count) {
      if (count < 0) result.add(object);
    });
    return result;
  }

  InternalToManyTestAccess(this._rel);
}
