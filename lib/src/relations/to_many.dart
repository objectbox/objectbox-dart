import 'dart:collection';
import 'dart:ffi';

import 'package:meta/meta.dart';
import 'package:objectbox/src/bindings/bindings.dart';
import 'package:objectbox/src/bindings/helpers.dart';

import 'internal.dart';
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
/// final student2 = Customer();
/// student2.teachers.add(teacher2);
///
/// // attach() must be called when creating new instances. On objects (e.g.
/// // "students" in this example) read with box.get() its done automatically.
/// student1.teachers.attach(store);
/// student2.teachers.attach(store);
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
  EntityDefinition<EntityT> _entity;

  RelInfo _rel;

  List<EntityT> /*?*/ __items;
  final _added = <EntityT>{};
  final _removed = <EntityT>{};

  void attach(Store store) {
    _store = store;
    _box = store.box<EntityT>();
    _entity = store.entityDef<EntityT>();
  }

  @override
  int get length => _items.length;

  @override
  set length(int newLength) {
    if (newLength < _items.length) {
      _items.getRange(newLength, _items.length).forEach(_remove);
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
      _remove(items[index]);
    }
    items[index] = element;
    _added.add(element);
    _removed.remove(element);
  }

  @override
  void add(EntityT element) {
    if (element == null) ArgumentError.notNull('element');
    _items.add(element);
    _added.add(element);
    _removed.remove(element);
  }

  @override
  void addAll(Iterable<EntityT> iterable) {
    iterable.forEach((element) {
      if (element == null) ArgumentError.notNull('element');
    });
    _items.addAll(iterable);
    _added.addAll(iterable);
    _removed.removeAll(iterable);
  }

  // note: to override, arg must be "Object", same as in the base class.
  @override
  bool remove(Object /*?*/ element) {
    if (!_items.remove(element)) return false;
    if (element != null) _remove(element);
    return true;
  }

  void _remove(EntityT object) {
    _added.remove(object);
    if (_entity.getId(object) ?? 0 != 0) {
      _removed.add(object);
    }
  }

  @override
  List<EntityT> toList({bool growable = true}) =>
      _items.toList(growable: growable);

  /// True if there are any changes not yet saved in DB.
  bool get hasPendingDbChanges => _added.isNotEmpty || _removed.isNotEmpty;

  /// Save changes made to this ToMany relation to the database. Alternatively,
  /// you can call box.put(object), its relations are automatically saved.
  ///
  /// If this collection contains new objects (with zero IDs),  applyToDb()
  /// will put them on-the-fly. For this to work the source object (the object
  /// owing this ToMany) must be already stored because its ID is required.
  void applyToDb() {
    if (!hasPendingDbChanges) return;
    _verifyAttached();

    if (_rel == null) {
      throw StateError("Relation info not initialized, can't applyToDb()");
    }

    switch (_rel.type) {
      case RelType.toMany:
        _store.runInTransactionWithPtr(TxMode.Write, (Pointer<OBX_txn> txn) {
          _added.forEach((EntityT object) {
            var id = _entity.getId(object) ?? 0;
            if (id == 0) id = _box.put(object);
            bindings.obx_box_rel_put(_box.ptr, _rel.id, _rel.objectId, id);
          });
          _removed.forEach((EntityT object) {
            var id = _entity.getId(object) ?? 0;
            if (id == 0) {
              throw Exception("Can't remove relation to an unstored object");
            }
            bindings.obx_box_rel_remove(_box.ptr, _rel.id, _rel.objectId, id);
          });
        });
        break;
      default:
        throw UnimplementedError();
    }

    _added.clear();
    _removed.clear();
  }

  /// Internal only, may change at any point.
  @internal
  Box<EntityT> get internalTargetBox {
    _verifyAttached();
    return _box;
  }

  /// Internal only, may change at any point.
  @internal
  void internalSetRelInfo(RelInfo rel) {
    _rel = rel;
  }

  List<EntityT> get _items => __items ??= _loadItems();

  List<EntityT> _loadItems() {
    if (_rel == null) {
      // Null _rel means this relation is used on a new (not stored) object.
      // Therefore, we're sure there are no stored items yet.
      return [];
    }
    _verifyAttached();
    switch (_rel.type) {
      case RelType.toMany:
        return __items = _getMany(() =>
            bindings.obx_box_rel_get_ids(_box.ptr, _rel.id, _rel.objectId));
        break;
      default:
        throw UnimplementedError();
    }
  }

  void _verifyAttached() {
    if (_box == null || _entity == null) {
      throw Exception('ToOne relation field not initialized. '
          'Make sure to call attach(store) before the first use.');
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
              final code = bindings.obx_cursor_get(
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
        bindings.obx_id_array_free(cIdsPtr);
      }
      return result;
    });
  }
}
