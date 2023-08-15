import 'dart:collection';

import 'package:meta/meta.dart';

import '../box.dart';
import '../modelinfo/entity_definition.dart';
import '../store.dart';
import '../transaction.dart';
import 'info.dart';

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
  /// Store-related configuration attached to this.
  ///
  /// This is to have a single place to store attached configuration and to
  /// support sending this across isolates, which does not support sending a
  /// Store which contains a pointer.
  ///
  /// Using dynamic for the owning entity type as adding it would require
  /// a breaking API change to ToMany (-> ToMany<EntityT, OwningEntityT>).
  _ToManyStoreConfiguration<EntityT, dynamic>? _storeConfiguration;

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
    if (__items == null) {
      // We don't need to load old data from DB to add new items.
      _addedBeforeLoad.add(element);
    } else {
      _items.add(element);
    }
  }

  @override
  void addAll(Iterable<EntityT> iterable) {
    iterable.forEach(_track);
    if (__items == null) {
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

  /// Save changes made to this ToMany relation to the database.
  ///
  /// This is an alternative to calling `box.put(object)` where `object` is the
  /// object owning this ToMany.
  ///
  /// If this contains new objects (IDs set to 0) they will be put. This
  /// requires the object owning this ToMany to already be stored because its ID
  /// is required.
  void applyToDb(
      {Store? existingStore, PutMode mode = PutMode.put, Transaction? tx}) {
    if (!_hasPendingDbChanges) return;

    final configuration = _getStoreConfigOrThrow();

    final relInfo = configuration.relInfo;
    if (relInfo.objectId == 0) {
      // The ID of the object owning this is required.
      throw StateError(
          "Can't store relation info for the target object with zero ID");
    }

    // Use given store, or obtain one via store configuration
    // (then store must be closed once done).
    final Store store = existingStore ??
        StoreInternal.attachByConfiguration(configuration.storeConfiguration);

    try {
      final ownedTx = tx == null;
      tx ??= Transaction(store, TxMode.write);
      try {
        _counts.forEach((EntityT object, count) {
          if (count == 0) return;
          final add = count > 0; // otherwise: remove
          var id = configuration.entity.getId(object) ?? 0;

          switch (relInfo.type) {
            case RelType.toMany:
              if (add) {
                if (id == 0) {
                  id = InternalBoxAccess.put(
                      configuration.box(store), object, mode, tx);
                }
                InternalBoxAccess.relPut(configuration.otherBox(store),
                    relInfo.id, relInfo.objectId, id);
              } else {
                if (id == 0) return;
                InternalBoxAccess.relRemove(configuration.otherBox(store),
                    relInfo.id, relInfo.objectId, id);
              }
              break;
            case RelType.toOneBacklink:
              final srcField = relInfo.toOneSourceField(object);
              srcField.targetId = add ? relInfo.objectId : null;
              configuration.box(store).put(object, mode: mode);
              break;
            case RelType.toManyBacklink:
              if (add) {
                if (id == 0) {
                  id = InternalBoxAccess.put(
                      configuration.box(store), object, mode, tx);
                }
                InternalBoxAccess.relPut(
                    configuration.box(store), relInfo.id, id, relInfo.objectId);
              } else {
                if (id == 0) return;
                InternalBoxAccess.relRemove(
                    configuration.box(store), relInfo.id, id, relInfo.objectId);
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
    } finally {
      // If store was temporarily created, close it.
      if (existingStore == null) {
        store.close();
      }
    }

    _counts.clear();
    _addedBeforeLoad.clear();
  }

  void _setRelInfo<OwningEntityT>(Store store, RelInfo relInfo) {
    final storeConfiguration = _storeConfiguration;
    if (storeConfiguration != null) {
      if (storeConfiguration.storeConfiguration.id !=
          store.configuration().id) {
        throw ArgumentError.value(
            store, 'store', 'Relation already attached to a different store');
      }
      return;
    }
    _storeConfiguration = _ToManyStoreConfiguration<EntityT, OwningEntityT>(
        store.configuration(),
        relInfo,
        InternalStoreAccess.entityDef<EntityT>(store));
  }

  _ToManyStoreConfiguration<EntityT, dynamic> _getStoreConfigOrThrow() {
    final storeConfiguration = _storeConfiguration;
    if (storeConfiguration == null) {
      throw StateError("ToMany relation field not initialized. "
          "Don't call applyToDb() on new objects, use box.put() instead.");
    }
    return storeConfiguration;
  }

  List<EntityT> get _items => __items ??= _loadItems();

  List<EntityT> _loadItems() {
    final List<EntityT> items;
    final configuration = _storeConfiguration;
    if (configuration == null) {
      // Null _storeConfiguration means this relation is used on a new
      // (not stored) object.
      // Therefore, this can be sure there are no stored items yet.
      items = [];
    } else {
      final store =
          StoreInternal.attachByConfiguration(configuration.storeConfiguration);
      items = InternalBoxAccess.getRelated(
          configuration.box(store), configuration.relInfo);
      store.close();
    }
    if (_addedBeforeLoad.isNotEmpty) {
      items.addAll(_addedBeforeLoad);
      _addedBeforeLoad.clear();
    }
    __items = items;
    return items;
  }
}

/// Internal only.
class InternalToManyAccess {
  /// Check whether the relation has any unsaved changes.
  @internal
  static bool hasPendingDbChanges(ToMany toMany) => toMany._hasPendingDbChanges;

  /// Set relation info.
  static void setRelInfo<OwningEntityT>(
          ToMany toMany, Store store, RelInfo rel) =>
      toMany._setRelInfo<OwningEntityT>(store, rel);
}

/// Internal only.
@visibleForTesting
class InternalToManyTestAccess<EntityT> {
  final ToMany<EntityT> _rel;

  /// Used in tests.
  bool get itemsLoaded => _rel.__items != null;

  /// Used in tests.
  List<EntityT> get items => _rel._items;

  /// Used in tests.
  Set<EntityT> get added {
    final result = <EntityT>{};
    _rel._counts.forEach((EntityT object, count) {
      if (count > 0) result.add(object);
    });
    return result;
  }

  /// Used in tests.
  Set<EntityT> get removed {
    final result = <EntityT>{};
    _rel._counts.forEach((EntityT object, count) {
      if (count < 0) result.add(object);
    });
    return result;
  }

  /// Used in tests.
  InternalToManyTestAccess(this._rel);
}

/// This stores the owning entity type with the store configuration.
class _ToManyStoreConfiguration<EntityT, OwningEntityT> {
  final StoreConfiguration storeConfiguration;
  final RelInfo relInfo;
  final EntityDefinition<EntityT> entity;

  _ToManyStoreConfiguration(this.storeConfiguration, this.relInfo, this.entity);

  /// Standard direction: target box; backlinks: source box.
  Box<EntityT> box(Store store) => store.box<EntityT>();

  /// Standard direction: source box; backlinks: target box.
  Box<OwningEntityT> otherBox(Store store) => store.box<OwningEntityT>();
}
