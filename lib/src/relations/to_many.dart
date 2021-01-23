import 'dart:collection';
import 'dart:ffi';

import 'package:meta/meta.dart';
import 'package:objectbox/src/bindings/bindings.dart';
import 'package:objectbox/src/bindings/helpers.dart';

import 'info.dart';
import '../box.dart';
import '../modelinfo/entity_definition.dart';
import '../store.dart';

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

  /*late final*/
  Box<EntityT> _box;

  /*late final*/
  Box _srcBox;

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
    if (element != null) _track(element, -1);
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
  bool get _hasPendingDbChanges =>
      _counts.values.where((c) => c != 0).isNotEmpty;

  // bool get _hasPendingDbChanges => _added.isNotEmpty || _removed.isNotEmpty;

  /// Save changes made to this ToMany relation to the database. Alternatively,
  /// you can call box.put(object), its relations are automatically saved.
  ///
  /// If this collection contains new objects (with zero IDs),  applyToDb()
  /// will put them on-the-fly. For this to work the source object (the object
  /// owing this ToMany) must be already stored because its ID is required.
  void applyToDb({PutMode mode = PutMode.Put}) {
    if (!_hasPendingDbChanges) return;
    _verifyAttached();

    if (_rel == null) {
      throw StateError("Relation info not initialized, can't applyToDb()");
    }

    switch (_rel.type) {
      case RelType.toMany:
        _store.runInTransactionWithPtr(TxMode.Write, (Pointer<OBX_txn> txn) {
          _counts.forEach((EntityT object, count) {
            if (count == 0) return;
            var id = _entity.getId(object) ?? 0;
            if (count > 0) {
              // added
              if (id == 0) id = _box.put(object, mode: mode);
              checkObx(
                  C.obx_box_rel_put(_srcBox.ptr, _rel.id, _rel.objectId, id));
            } else {
              // removed
              if (id == 0) return;
              checkObx(C.obx_box_rel_remove(
                  _srcBox.ptr, _rel.id, _rel.objectId, id));
            }
          });
        });
        break;
      default:
        throw UnimplementedError();
    }

    _counts.clear();
  }

  /// Internal only, may change at any point.
  void internalSetRelInfo(Store store, RelInfo rel, Box srcBox) {
    _store = store;
    _box = store.box<EntityT>();
    _entity = store.entityDef<EntityT>();
    _rel = rel;
    _srcBox = srcBox;
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
              () => C.obx_box_rel_get_ids(_box.ptr, _rel.id, _rel.objectId));
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
    return _store.runInTransactionWithPtr(TxMode.Read, (Pointer<OBX_txn> txn) {
      final result = <EntityT>[];
      final cIdsPtr = checkObxPtr(cIdsGetterFn());
      try {
        final cIds = cIdsPtr.ref;
        if (cIds.count > 0) {
          final cursor = CursorHelper(txn, _entity, false);
          try {
            for (var i = 0; i < cIds.count; i++) {
              final code = C.obx_cursor_get(
                  cursor.ptr, cIds.ids[i], cursor.dataPtrPtr, cursor.sizePtr);
              if (code != OBX_NOT_FOUND) {
                checkObx(code);
                result.add(_entity.objectFromFB(_store, cursor.readData));
              }
            }
          } finally {
            cursor.close();
          }
        }
      } finally {
        C.obx_id_array_free(cIdsPtr);
      }
      return result;
    });
  }
}

@internal
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
