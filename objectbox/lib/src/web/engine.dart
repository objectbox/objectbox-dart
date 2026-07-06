// The web database engine backing the web implementation of Store/Box:
// an in-memory, synchronous store (matching the synchronous ObjectBox API)
// persisted to IndexedDB with a write-behind queue.
//
// Design notes:
// - All reads/writes operate on in-memory maps so the synchronous Box API
//   keeps its native semantics. Persisted data is loaded once, asynchronously,
//   when the store is opened: await `Store.ready` (generated `openStore()` for
//   Flutter apps does this) before using the store.
// - Every mutation marks records dirty; a microtask flushes the batch into a
//   single IndexedDB transaction. `Store.awaitQueueCompletion()` awaits the
//   queue. Durability is therefore slightly weaker than native ObjectBox
//   (a browser crash can lose the last moments of writes).
// - Write "transactions" (runInTransaction/relations puts) are implemented
//   with an undo log: on abort/error the in-memory state is restored and the
//   restored records are re-marked dirty.
// - `memory:` directories (Store.inMemoryPrefix) skip IndexedDB entirely.
// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:collection';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../common.dart';
import '../modelinfo/entity_definition.dart';
import '../modelinfo/enums.dart';
import '../modelinfo/model_definition.dart';
import '../modelinfo/modelentity.dart';
import '../modelinfo/modelproperty.dart';
import '../store_config.dart';
import 'fb_reader.dart';
import 'idb_util.dart';

const String metaStoreName = '__obx_meta__';
const String relStoreName = '__obx_rel__';

class EntityData {
  final ModelEntity model;
  final EntityDefinition definition;

  /// Records by id, sorted so getAll() returns objects in id order like the
  /// native implementation.
  final SplayTreeMap<int, Uint8List> records = SplayTreeMap<int, Uint8List>();

  /// Highest id ever assigned (ids of removed objects are not reused).
  int lastId = 0;

  final List<ModelProperty> uniqueProperties;

  /// Unique index: property model id -> value -> object id.
  final Map<int, Map<Object, int>> uniqueIndex = {};

  /// ToOne properties of this entity (relation type), for backlinks and
  /// cleanup of references when targets are removed.
  final List<ModelProperty> relationProperties;

  EntityData(this.model, this.definition)
      : uniqueProperties = model.properties
            .where((p) => p.hasFlag(OBXPropertyFlags.UNIQUE))
            .toList(growable: false),
        relationProperties = model.properties
            .where((p) => p.type == OBXPropertyType.Relation)
            .toList(growable: false) {
    for (final property in uniqueProperties) {
      uniqueIndex[property.id.id] = {};
    }
  }

  bool get idSelfAssignable =>
      model.idProperty.hasFlag(OBXPropertyFlags.ID_SELF_ASSIGNABLE);

  void indexUniques(int id, Uint8List bytes) {
    for (final property in uniqueProperties) {
      final value = readProperty(property, _view(bytes));
      if (value != null) uniqueIndex[property.id.id]![value] = id;
    }
  }

  void unindexUniques(int id, Uint8List bytes) {
    for (final property in uniqueProperties) {
      final value = readProperty(property, _view(bytes));
      if (value != null) {
        final index = uniqueIndex[property.id.id]!;
        if (index[value] == id) index.remove(value);
      }
    }
  }

  void rebuildUniqueIndex() {
    for (final index in uniqueIndex.values) {
      index.clear();
    }
    records.forEach(indexUniques);
  }
}

ByteData _view(Uint8List bytes) =>
    ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);

class _UndoLog {
  /// First-touch snapshot of records: entity id -> object id -> old bytes
  /// (null if the record did not exist).
  final Map<int, Map<int, Uint8List?>> records = {};

  /// First-touch snapshot of id sequences.
  final Map<int, int> lastIds = {};

  /// First-touch snapshot of relation target sets:
  /// relation id -> source id -> old targets (null if absent).
  final Map<int, Map<int, Set<int>?>> relations = {};
}

class _DirtyEntityStore {
  bool cleared = false;

  /// id -> bytes (null = delete)
  final Map<int, Uint8List?> entries = {};
}

class WebStoreEngine {
  static int _nextId = 1;

  final String directoryPath;
  final ModelDefinition modelDefinition;
  final bool inMemory;
  final StoreConfiguration configuration;

  /// Number of Store handles sharing this engine (Store.attach & relations).
  int refCount = 1;

  /// Close listeners registered via InternalStoreAccess.
  final Map<dynamic, void Function()> closeListeners = {};

  final Future<void>? _awaitBeforeOpen;

  /// Entity data by entity model id.
  final Map<int, EntityData> entities = {};
  final Map<Type, EntityData> entitiesByType = {};

  /// Standalone ToMany relations: relation id -> source id -> target ids.
  final Map<int, Map<int, Set<int>>> relations = {};

  /// Relation ids by source/target entity id (for cleanup on remove).
  final Map<int, List<int>> _relIdsBySourceEntity = {};
  final Map<int, List<int>> _relIdsByTargetEntity = {};

  web.IDBDatabase? _db;
  late final Future<void> ready;
  bool _closed = false;

  // Transaction state (single-threaded, so a plain depth counter suffices).
  int _txDepth = 0;
  _UndoLog? _undo;

  // Write-behind queue.
  final Map<String, _DirtyEntityStore> _dirtyEntities = {};
  final Map<String, List<int>?> _dirtyRelations = {}; // 'relId:srcId' -> ids
  final Map<String, int> _dirtyMeta = {};
  bool _flushScheduled = false;
  Future<void> _flushChain = Future.value();

  // Change notifications.
  final StreamController<List<Type>> changes =
      StreamController<List<Type>>.broadcast();
  final Set<Type> _pendingChanges = {};

  WebStoreEngine(this.modelDefinition, this.directoryPath,
      {required bool queriesCaseSensitiveDefault,
      Future<void>? awaitBeforeOpen})
      : inMemory = directoryPath.startsWith('memory:'),
        _awaitBeforeOpen = awaitBeforeOpen,
        configuration = StoreConfiguration(_nextId++, modelDefinition,
            directoryPath, queriesCaseSensitiveDefault) {
    for (final entity in modelDefinition.model.entities) {
      final definition = modelDefinition.bindings.values.firstWhere(
          (definition) => definition.model.id.id == entity.id.id,
          orElse: () => throw SchemaException(
              'No binding for entity ${entity.name} - model out of sync'));
      final data = EntityData(entity, definition);
      entities[entity.id.id] = data;
      entitiesByType[definition.type()] = data;
      for (final relation in entity.relations) {
        relations[relation.id.id] = {};
        _relIdsBySourceEntity
            .putIfAbsent(entity.id.id, () => [])
            .add(relation.id.id);
        _relIdsByTargetEntity
            .putIfAbsent(relation.targetId.id, () => [])
            .add(relation.id.id);
      }
    }
    ready = inMemory ? Future.value() : _load();
  }

  bool get isClosed => _closed;

  void checkOpen() {
    if (_closed) throw StateError('Store is closed');
  }

  EntityData entityByType(Type type) {
    final data = entitiesByType[type];
    if (data == null) {
      throw ArgumentError(
          'Unknown entity type $type - did you run the generator?');
    }
    return data;
  }

  // ---------------------------------------------------------------- loading

  Future<void> _load() async {
    // Wait for a previous engine on the same path to finish closing.
    if (_awaitBeforeOpen != null) {
      try {
        await _awaitBeforeOpen;
      } catch (_) {
        // The old engine failed to flush cleanly; open anyway.
      }
    }
    final storeNames = [
      metaStoreName,
      relStoreName,
      for (final data in entities.values) data.model.name
    ];
    final db = await idbOpen(directoryPath, storeNames);
    _db = db;

    // Best-effort request for persistent (non-evictable) storage.
    try {
      web.window.navigator.storage.persist();
    } catch (_) {
      // Not available (e.g. non-secure context) - ignore.
    }

    for (final data in entities.values) {
      for (final (id, value) in await idbReadAll(db, data.model.name)) {
        if (value == null) continue;
        final bytes = (value as JSUint8Array).toDart;
        data.records[id] = bytes;
        if (id > data.lastId) data.lastId = id;
      }
      data.rebuildUniqueIndex();
    }

    for (final (key, value) in await idbReadAllStringKeys(db, metaStoreName)) {
      if (!key.startsWith('seq:')) continue;
      final entityName = key.substring(4);
      for (final data in entities.values) {
        if (data.model.name == entityName) {
          final sequence = (value as JSNumber).toDartInt;
          if (sequence > data.lastId) data.lastId = sequence;
        }
      }
    }

    for (final (key, value) in await idbReadAllStringKeys(db, relStoreName)) {
      final separator = key.indexOf(':');
      if (separator <= 0 || value == null) continue;
      final relId = int.parse(key.substring(0, separator));
      final sourceId = int.parse(key.substring(separator + 1));
      final targetMap = relations[relId];
      if (targetMap == null) continue; // relation removed from model
      final ids = (value as JSArray).toDart;
      targetMap[sourceId] = {for (final id in ids) (id as JSNumber).toDartInt};
    }
  }

  // ----------------------------------------------------------- transactions

  void beginTx() {
    checkOpen();
    if (_txDepth == 0) _undo = _UndoLog();
    _txDepth++;
  }

  void commitTx() {
    _txDepth--;
    if (_txDepth == 0) {
      _undo = null;
      _emitChanges();
      _scheduleFlush();
    }
  }

  void abortTx() {
    _txDepth--;
    if (_txDepth > 0) {
      // Match native semantics loosely: an inner abort fails the whole
      // transaction. Rethrowing from the failed inner scope (which is how
      // aborts happen here) propagates the abort outwards.
      return;
    }
    final undo = _undo!;
    _undo = null;

    undo.records.forEach((entityId, snapshots) {
      final data = entities[entityId]!;
      snapshots.forEach((id, oldBytes) {
        if (oldBytes == null) {
          data.records.remove(id);
        } else {
          data.records[id] = oldBytes;
        }
        _markDirty(data.model.name, id, oldBytes);
      });
      data.rebuildUniqueIndex();
    });
    undo.lastIds.forEach((entityId, lastId) {
      entities[entityId]!.lastId = lastId;
      _markMetaDirty(entities[entityId]!);
    });
    undo.relations.forEach((relId, snapshots) {
      final targetMap = relations[relId]!;
      snapshots.forEach((sourceId, oldTargets) {
        if (oldTargets == null) {
          targetMap.remove(sourceId);
        } else {
          targetMap[sourceId] = oldTargets;
        }
        _markRelDirty(relId, sourceId);
      });
    });
    _pendingChanges.clear();
    _scheduleFlush();
  }

  R runInTx<R>(R Function() action) {
    beginTx();
    try {
      final result = action();
      commitTx();
      return result;
    } catch (e) {
      abortTx();
      rethrow;
    }
  }

  void _snapshotRecord(EntityData data, int id) {
    final undo = _undo;
    if (undo == null) return;
    undo.records
        .putIfAbsent(data.model.id.id, () => {})
        .putIfAbsent(id, () => data.records[id]);
  }

  void _snapshotLastId(EntityData data) {
    _undo?.lastIds.putIfAbsent(data.model.id.id, () => data.lastId);
  }

  void _snapshotRelation(int relId, int sourceId) {
    final undo = _undo;
    if (undo == null) return;
    undo.relations.putIfAbsent(relId, () => {}).putIfAbsent(
        sourceId,
        () => relations[relId]![sourceId] == null
            ? null
            : Set<int>.of(relations[relId]![sourceId]!));
  }

  // ------------------------------------------------------------------- CRUD

  int reserveId(EntityData data) {
    checkOpen();
    _snapshotLastId(data);
    final id = ++data.lastId;
    _markMetaDirty(data);
    return id;
  }

  /// Stores serialized [bytes] under [id]. The caller (Box) has already
  /// assigned the id and enforced PutMode semantics via [checkPutId].
  void putRecord(EntityData data, int id, Uint8List bytes) {
    checkOpen();
    _checkUniques(data, id, bytes);
    _snapshotRecord(data, id);
    final oldBytes = data.records[id];
    if (oldBytes != null) data.unindexUniques(id, oldBytes);
    data.records[id] = bytes;
    data.indexUniques(id, bytes);
    if (id > data.lastId) {
      _snapshotLastId(data);
      data.lastId = id;
      _markMetaDirty(data);
    }
    _markDirty(data.model.name, id, bytes);
    _noteChange(data);
  }

  /// Validates [PutMode]-like semantics and returns the id to use.
  int checkPutId(EntityData data, int id, int mode) {
    checkOpen();
    final exists = id != 0 && data.records.containsKey(id);
    // OBXPutMode: 1 = PUT, 2 = INSERT, 3 = UPDATE
    if (mode == 2 && exists) {
      throw ObjectBoxException(
          'object put failed: ID $id already exists (mode insert)');
    }
    if (mode == 3 && !exists) {
      throw ObjectBoxException(
          'object put failed: ID $id does not exist (mode update)');
    }
    if (id == 0) return reserveId(data);
    if (id > data.lastId) {
      if (!data.idSelfAssignable) {
        throw ArgumentError(
            'object put failed: ID $id is higher than the internal ID sequence'
            ' (${data.lastId}); use @Id(assignable: true) to assign IDs');
      }
    }
    return id;
  }

  void _checkUniques(EntityData data, int id, Uint8List bytes) {
    for (final property in data.uniqueProperties) {
      final value = readProperty(property, _view(bytes));
      if (value == null) continue;
      final existingId = data.uniqueIndex[property.id.id]![value];
      if (existingId != null && existingId != id) {
        if (property.hasFlag(OBXPropertyFlags.UNIQUE_ON_CONFLICT_REPLACE)) {
          removeRecord(data, existingId);
        } else {
          throw UniqueViolationException(
              'Unique constraint for ${data.model.name}.${property.name}'
              ' would be violated by putting value "$value"');
        }
      }
    }
  }

  Uint8List? getRecord(EntityData data, int id) {
    checkOpen();
    return data.records[id];
  }

  bool removeRecord(EntityData data, int id) {
    checkOpen();
    final oldBytes = data.records[id];
    if (oldBytes == null) return false;
    _snapshotRecord(data, id);
    data.records.remove(id);
    data.unindexUniques(id, oldBytes);
    _markDirty(data.model.name, id, null);
    _removeRelationsOf(data, id);
    _noteChange(data);
    return true;
  }

  int removeAllRecords(EntityData data) {
    checkOpen();
    final count = data.records.length;
    if (_undo != null) {
      // Snapshot every record for rollback.
      for (final id in data.records.keys.toList(growable: false)) {
        _snapshotRecord(data, id);
      }
    }
    final ids = data.records.keys.toList(growable: false);
    data.records.clear();
    data.rebuildUniqueIndex();
    if (!inMemory) {
      final dirty =
          _dirtyEntities.putIfAbsent(data.model.name, _DirtyEntityStore.new);
      dirty.cleared = true;
      dirty.entries.clear();
      _scheduleFlush();
    }
    for (final id in ids) {
      _removeRelationsOf(data, id);
    }
    _noteChange(data);
    return count;
  }

  void _removeRelationsOf(EntityData data, int id) {
    // Remove standalone relation rows where the object is the source ...
    for (final relId
        in _relIdsBySourceEntity[data.model.id.id] ?? const <int>[]) {
      final targetMap = relations[relId]!;
      if (targetMap.containsKey(id)) {
        _snapshotRelation(relId, id);
        targetMap.remove(id);
        _markRelDirty(relId, id);
      }
    }
    // ... and where it is the target.
    for (final relId
        in _relIdsByTargetEntity[data.model.id.id] ?? const <int>[]) {
      final targetMap = relations[relId]!;
      targetMap.forEach((sourceId, targets) {
        if (targets.contains(id)) {
          _snapshotRelation(relId, sourceId);
          targets.remove(id);
          _markRelDirty(relId, sourceId);
        }
      });
    }
  }

  // -------------------------------------------------------------- relations

  void relPut(int relId, int sourceId, int targetId) {
    checkOpen();
    final targetMap = relations[relId];
    if (targetMap == null) {
      throw ArgumentError('Unknown standalone relation ID $relId');
    }
    _snapshotRelation(relId, sourceId);
    targetMap.putIfAbsent(sourceId, () => {}).add(targetId);
    _markRelDirty(relId, sourceId);
  }

  void relRemove(int relId, int sourceId, int targetId) {
    checkOpen();
    final targetMap = relations[relId];
    if (targetMap == null) {
      throw ArgumentError('Unknown standalone relation ID $relId');
    }
    _snapshotRelation(relId, sourceId);
    final targets = targetMap[sourceId];
    if (targets != null) {
      targets.remove(targetId);
      if (targets.isEmpty) targetMap.remove(sourceId);
    }
    _markRelDirty(relId, sourceId);
  }

  List<int> relTargets(int relId, int sourceId) {
    checkOpen();
    final targets = relations[relId]?[sourceId];
    return targets == null ? const [] : (targets.toList()..sort());
  }

  List<int> relBacklinkSources(int relId, int targetId) {
    checkOpen();
    final targetMap = relations[relId];
    if (targetMap == null) return const [];
    final sources = <int>[];
    targetMap.forEach((sourceId, targets) {
      if (targets.contains(targetId)) sources.add(sourceId);
    });
    return sources..sort();
  }

  /// Source ids of [sourceData] records whose ToOne property [propertyId]
  /// points at [targetId] (one-to-many backlink).
  List<int> toOneBacklinkSources(
      EntityData sourceData, int propertyId, int targetId) {
    checkOpen();
    final property = sourceData.model.properties
        .firstWhere((property) => property.id.id == propertyId);
    final sources = <int>[];
    sourceData.records.forEach((id, bytes) {
      if (readIntProperty(property, _view(bytes)) == targetId) {
        sources.add(id);
      }
    });
    return sources;
  }

  // ------------------------------------------------------------ persistence

  void _markDirty(String storeName, int id, Uint8List? bytes) {
    if (inMemory) return;
    _dirtyEntities.putIfAbsent(storeName, _DirtyEntityStore.new).entries[id] =
        bytes;
    _scheduleFlush();
  }

  void _markRelDirty(int relId, int sourceId) {
    if (inMemory) return;
    _dirtyRelations['$relId:$sourceId'] = relations[relId]![sourceId]?.toList();
    _scheduleFlush();
  }

  void _markMetaDirty(EntityData data) {
    if (inMemory) return;
    _dirtyMeta['seq:${data.model.name}'] = data.lastId;
    _scheduleFlush();
  }

  void _scheduleFlush() {
    if (inMemory || _flushScheduled || _txDepth > 0) return;
    _flushScheduled = true;
    _flushChain = _flushChain.then((_) => _flush());
  }

  Future<void> _flush() async {
    // Let the current synchronous batch of mutations finish first.
    await Future<void>.delayed(Duration.zero);
    _flushScheduled = false;
    if (_dirtyEntities.isEmpty &&
        _dirtyRelations.isEmpty &&
        _dirtyMeta.isEmpty) {
      return;
    }
    await ready;
    final db = _db;
    if (db == null) return;

    final entityBatch = Map.of(_dirtyEntities);
    final relBatch = Map.of(_dirtyRelations);
    final metaBatch = Map.of(_dirtyMeta);
    _dirtyEntities.clear();
    _dirtyRelations.clear();
    _dirtyMeta.clear();

    final storeNames = <String>{
      ...entityBatch.keys,
      if (relBatch.isNotEmpty) relStoreName,
      if (metaBatch.isNotEmpty) metaStoreName,
    };
    if (storeNames.isEmpty) return;

    final transaction = db.transaction(
        storeNames.map((name) => name.toJS).toList().toJS, 'readwrite');
    entityBatch.forEach((storeName, dirty) {
      final store = transaction.objectStore(storeName);
      if (dirty.cleared) store.clear();
      dirty.entries.forEach((id, bytes) {
        if (bytes == null) {
          store.delete(id.toJS);
        } else {
          store.put(bytes.toJS, id.toJS);
        }
      });
    });
    if (relBatch.isNotEmpty) {
      final store = transaction.objectStore(relStoreName);
      relBatch.forEach((key, targets) {
        if (targets == null) {
          store.delete(key.toJS);
        } else {
          store.put(targets.map((id) => id.toJS).toList().toJS, key.toJS);
        }
      });
    }
    if (metaBatch.isNotEmpty) {
      final store = transaction.objectStore(metaStoreName);
      metaBatch.forEach((key, value) {
        store.put(value.toJS, key.toJS);
      });
    }
    await idbTransactionDone(transaction);
  }

  /// Completes when all currently queued writes have been persisted.
  Future<void> awaitQueueCompletion() async {
    await ready;
    // The chain may grow while we wait; loop until it is stable.
    Future<void> current;
    do {
      current = _flushChain;
      await current;
    } while (!identical(current, _flushChain));
  }

  // ----------------------------------------------------------------- events

  void _noteChange(EntityData data) {
    _pendingChanges.add(data.definition.type());
    if (_txDepth == 0) _emitChanges();
  }

  void _emitChanges() {
    if (_pendingChanges.isEmpty) return;
    final changed = _pendingChanges.toList(growable: false);
    _pendingChanges.clear();
    if (changes.hasListener) changes.add(changed);
  }

  // ------------------------------------------------------------------ close

  void notifyCloseListeners() {
    for (final listener in closeListeners.values.toList(growable: false)) {
      listener();
    }
    closeListeners.clear();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    changes.close();
    if (!inMemory) {
      try {
        await ready;
        await awaitQueueCompletion();
      } finally {
        _db?.close();
        _db = null;
      }
    }
  }
}
