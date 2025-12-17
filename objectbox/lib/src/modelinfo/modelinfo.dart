import 'dart:math';

import 'iduid.dart';
import 'modelentity.dart';

// ignore_for_file: public_member_api_docs

const _minModelVersion = 5;
const _maxModelVersion = 5;

/// Represents the generator version used to create the model.
///
/// This enum contains all supported versions by this ObjectBox runtime library.
/// It is used purely for compile-time enforcement to ensure users regenerate
/// code after updating the objectbox package.
/// Once a version is not compatible/supported, it is removed from this enum.
/// Note: using a separate, date based, versioning (YYYY_MM_DD) as the
/// generator is not always updated in each library version.
enum GeneratorVersion {
  /// The model was not created by generated code.
  none,

  /// Generator for ObjectBox Dart 5.1 (introduced the GeneratorVersion enum)
  v2025_12_16,
}

/// The latest generator version (aligned with this ObjectBox runtime library).
const generatorVersionLatest = GeneratorVersion.v2025_12_16;

/// In order to represent the model stored in `objectbox-model.json` in Dart,
/// several classes have been introduced. Conceptually, these classes are
/// comparable to how models are handled in ObjectBox Java and ObjectBox Go.
/// This is also why for explanations on most concepts related to ObjectBox
/// models, you can refer to https://docs.objectbox.io/advanced.
class ModelInfo {
  static const notes = [
    'KEEP THIS FILE! Check it into a version control system (VCS) like git.',
    'ObjectBox manages crucial IDs for your object model. See docs for details.',
    'If you have VCS merge conflicts, you must resolve them according to ObjectBox docs.',
  ];

  /// The ObjectBox Dart generator version used to generate this model.
  GeneratorVersion generatorVersion;

  List<ModelEntity> entities;
  IdUid lastEntityId, lastIndexId, lastRelationId, lastSequenceId;
  List<int> retiredEntityUids,
      retiredIndexUids,
      retiredPropertyUids,
      retiredRelationUids;
  int modelVersion, modelVersionParserMinimum, version;

  ModelInfo(
      {required this.generatorVersion,
      required this.entities,
      required this.lastEntityId,
      required this.lastIndexId,
      required this.lastRelationId,
      required this.lastSequenceId,
      required this.retiredEntityUids,
      required this.retiredIndexUids,
      required this.retiredPropertyUids,
      required this.retiredRelationUids,
      required this.modelVersion,
      required this.modelVersionParserMinimum,
      required this.version});

  ModelInfo.empty()
      : generatorVersion = GeneratorVersion.none,
        entities = [],
        lastEntityId = const IdUid.empty(),
        lastIndexId = const IdUid.empty(),
        lastRelationId = const IdUid.empty(),
        lastSequenceId = const IdUid.empty(),
        retiredEntityUids = [],
        retiredIndexUids = [],
        retiredPropertyUids = [],
        retiredRelationUids = [],
        modelVersion = _maxModelVersion,
        modelVersionParserMinimum = _maxModelVersion,
        version = 1;

  ModelInfo.fromMap(Map<String, dynamic> data, {bool check = true})
      : generatorVersion = GeneratorVersion.none,
        entities = [],
        lastEntityId = IdUid.fromString(data['lastEntityId'] as String?),
        lastIndexId = IdUid.fromString(data['lastIndexId'] as String?),
        lastRelationId = IdUid.fromString(data['lastRelationId'] as String?),
        lastSequenceId = IdUid.fromString(data['lastSequenceId'] as String?),
        retiredEntityUids = _uids(data['retiredEntityUids']),
        retiredIndexUids = _uids(data['retiredIndexUids']),
        retiredPropertyUids = _uids(data['retiredPropertyUids']),
        retiredRelationUids = _uids(data['retiredRelationUids']),
        modelVersion = data['modelVersion'] as int? ?? 0,
        modelVersionParserMinimum =
            data['modelVersionParserMinimum'] as int? ?? _maxModelVersion,
        version = data['version'] as int? ?? 1 {
    final entities = data['entities'] as List;
    for (final e in entities) {
      this.entities.add(ModelEntity.fromMap(e as Map<String, dynamic>,
          model: this, check: check));
    }
    if (check) validate();
  }

  void validate() {
    if (modelVersion < _minModelVersion) {
      throw StateError(
          'the loaded model is too old: version $modelVersion while the minimum supported is $_minModelVersion, consider upgrading with an older generator or manually');
    }
    if (modelVersion > _maxModelVersion) {
      throw StateError(
          'the loaded model has been created with a newer generator version $modelVersion, while the maximum supported version is $_maxModelVersion. Please upgrade your toolchain/generator');
    }

    var lastEntityIdFound = false;
    for (final e in entities) {
      if (e.model != this) {
        throw StateError(
            "entity '${e.name}' with id ${e.id} has incorrect parent model reference");
      }
      e.validate();
      if (lastEntityId.id < e.id.id) {
        throw StateError(
            "lastEntityId $lastEntityId is lower than the one of entity '${e.name}' with id ${e.id}");
      }
      if (lastEntityId.id == e.id.id) {
        if (lastEntityId.uid != e.id.uid) {
          throw StateError(
              "lastEntityId $lastEntityId does not match entity '${e.name}' with id ${e.id}");
        }
        lastEntityIdFound = true;
      }
    }

    if (!lastEntityIdFound && !retiredEntityUids.contains(lastEntityId.uid)) {
      throw StateError('lastEntityId $lastEntityId does not match any entity');
    }

    if (!lastRelationId.isEmpty || hasRelations()) {
      var lastRelationIdFound = false;
      for (final e in entities) {
        for (final r in e.relations) {
          if (lastRelationId.id < r.id.id) {
            throw StateError(
                "lastRelationId $lastRelationId is lower than the one of relation '${r.name}' with id ${r.id}");
          }
          if (lastRelationId.id == r.id.id) {
            if (lastRelationId.uid != r.id.uid) {
              throw StateError(
                  "lastRelationId $lastRelationId does not match relation '${r.name}' with id ${r.id}");
            }
            lastRelationIdFound = true;
          }
        }
      }

      if (!lastRelationIdFound &&
          !retiredRelationUids.contains(lastRelationId.uid)) {
        throw StateError(
            'lastRelationId $lastRelationId does not match any standalone relation');
      }
    }
  }

  /// Convert to a string map to be used in the model JSON file.
  Map<String, dynamic> toMap() {
    final ret = <String, dynamic>{};
    ret['_note1'] = notes[0];
    ret['_note2'] = notes[1];
    ret['_note3'] = notes[2];
    ret['entities'] = entities.map((e) => e.toMap(forModelJson: true)).toList();
    ret['lastEntityId'] = lastEntityId.toString();
    ret['lastIndexId'] = lastIndexId.toString();
    ret['lastRelationId'] = lastRelationId.toString();
    ret['lastSequenceId'] = lastSequenceId.toString();
    ret['modelVersion'] = modelVersion;
    ret['modelVersionParserMinimum'] = modelVersionParserMinimum;
    ret['retiredEntityUids'] = retiredEntityUids;
    ret['retiredIndexUids'] = retiredIndexUids;
    ret['retiredPropertyUids'] = retiredPropertyUids;
    ret['retiredRelationUids'] = retiredRelationUids;
    ret['version'] = version;
    return ret;
  }

  ModelEntity getEntityByUid(int uid) {
    final entity = findEntityByUid(uid);
    if (entity == null) throw StateError('entity uid=$uid not found');
    return entity;
  }

  ModelEntity? findEntityByUid(int uid) {
    final idx = entities.indexWhere((e) => e.id.uid == uid);
    return idx < 0 ? null : entities[idx];
  }

  ModelEntity? findEntityByName(String name) {
    final found = entities
        .where((e) => e.name.toLowerCase() == name.toLowerCase())
        .toList();
    if (found.isEmpty) return null;
    if (found.length >= 2) {
      throw StateError(
          'ambiguous entity name: $name; please specify a UID in its annotation');
    }
    return found[0];
  }

  ModelEntity? findSameEntity(ModelEntity other) => other.id.uid == 0
      ? findEntityByName(other.name)
      : findEntityByUid(other.id.uid);

  ModelEntity createEntity(String name, [int uid = 0]) {
    final id = lastEntityId.id + 1;
    if (uid != 0 && containsUid(uid)) {
      throw StateError('uid already exists: $uid');
    }
    final uniqueUid = uid == 0 ? generateUid() : uid;

    var entity = ModelEntity.create(IdUid(id, uniqueUid), name, this);
    entities.add(entity);
    lastEntityId = entity.id;
    return entity;
  }

  void removeEntity(ModelEntity entity) {
    final foundEntity = findSameEntity(entity);
    if (foundEntity == null) {
      throw StateError(
          "cannot remove entity '${entity.name}' with id ${entity.id}: not found");
    }
    entities = entities.where((p) => p != foundEntity).toList();
    retiredEntityUids.add(entity.id.uid);
    for (var prop in entity.properties) {
      retiredPropertyUids.add(prop.id.uid);
    }
  }

  int generateUid() {
    var rng = Random();
    for (var i = 0; i < 1000; ++i) {
      // Dart can only generate random numbers up to 1 << 32, so concat two of them and remove the upper bit to make the number non-negative
      var uid = rng.nextInt(1 << 32);
      uid |= rng.nextInt(1 << 32) << 32;
      uid &= ~(1 << 63);
      if (uid != 0 && !containsUid(uid)) return uid;
    }

    throw StateError('internal error: could not generate a unique UID');
  }

  bool containsUid(int uid) {
    if (lastEntityId.uid == uid) return true;
    if (lastIndexId.uid == uid) return true;
    if (lastRelationId.uid == uid) return true;
    if (lastSequenceId.uid == uid) return true;
    if (entities.indexWhere((e) => e.containsUid(uid)) != -1) return true;
    if (retiredEntityUids.contains(uid)) return true;
    if (retiredIndexUids.contains(uid)) return true;
    if (retiredPropertyUids.contains(uid)) return true;
    if (retiredRelationUids.contains(uid)) return true;
    return false;
  }

  IdUid createIndexId() {
    final id = lastIndexId.id + 1;
    lastIndexId = IdUid(id, generateUid());
    return lastIndexId;
  }

  bool hasRelations() =>
      entities.indexWhere((e) => e.relations.isNotEmpty) != -1;
}

List<int> _uids(dynamic list) =>
    list == null ? [] : List<int>.from(list as List<dynamic>);
