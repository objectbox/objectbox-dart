import "dart:math";

import '../util.dart';
import "modelentity.dart";
import "iduid.dart";

const _minModelVersion = 5;
const _maxModelVersion = 5;

/// In order to represent the model stored in `objectbox-model.json` in Dart, several classes have been introduced.
/// Conceptually, these classes are comparable to how models are handled in ObjectBox Java and ObjectBox Go; eventually,
/// ObjectBox Dart models will be fully compatible to them. This is also why for explanations on most concepts related
/// to ObjectBox models, you can refer to the [existing documentation](https://docs.objectbox.io/advanced).
class ModelInfo {
  static const notes = [
    "KEEP THIS FILE! Check it into a version control system (VCS) like git.",
    "ObjectBox manages crucial IDs for your object model. See docs for details.",
    "If you have VCS merge conflicts, you must resolve them according to ObjectBox docs.",
  ];

  List<ModelEntity> entities;
  IdUid lastEntityId, lastIndexId, lastRelationId, lastSequenceId;
  List<int> retiredEntityUids, retiredIndexUids, retiredPropertyUids, retiredRelationUids;
  int modelVersion, modelVersionParserMinimum, version;

  ModelInfo(
      {this.entities,
      this.lastEntityId,
      this.lastIndexId,
      this.lastRelationId,
      this.lastSequenceId,
      this.retiredEntityUids,
      this.retiredIndexUids,
      this.retiredPropertyUids,
      this.retiredRelationUids,
      this.modelVersion,
      this.modelVersionParserMinimum,
      this.version});

  ModelInfo.createDefault()
      : entities = [],
        lastEntityId = IdUid.empty(),
        lastIndexId = IdUid.empty(),
        lastRelationId = IdUid.empty(),
        lastSequenceId = IdUid.empty(),
        retiredEntityUids = [],
        retiredIndexUids = [],
        retiredPropertyUids = [],
        retiredRelationUids = [],
        modelVersion = _maxModelVersion,
        modelVersionParserMinimum = _maxModelVersion,
        version = 1;

  ModelInfo.fromMap(Map<String, dynamic> data, {bool check = true}) {
    lastEntityId = IdUid.fromString(data["lastEntityId"]);
    lastIndexId = IdUid.fromString(data["lastIndexId"]);
    lastRelationId = IdUid.fromString(data["lastRelationId"]);
    lastSequenceId = IdUid.fromString(data["lastSequenceId"]);
    modelVersion = data["modelVersion"];
    modelVersionParserMinimum = data["modelVersionParserMinimum"];
    retiredEntityUids = List<int>.from(data["retiredEntityUids"] ?? []);
    retiredIndexUids = List<int>.from(data["retiredIndexUids"] ?? []);
    retiredPropertyUids = List<int>.from(data["retiredPropertyUids"] ?? []);
    retiredRelationUids = List<int>.from(data["retiredRelationUids"] ?? []);
    version = data["version"];
    entities = data["entities"].map<ModelEntity>((e) => ModelEntity.fromMap(e, model: this, check: check)).toList();
    if (check) validate();
  }

  void validate() {
    if (modelVersion < _minModelVersion) {
      throw Exception(
          "the loaded model is too old: version $modelVersion while the minimum supported is $_minModelVersion, consider upgrading with an older generator or manually");
    }
    if (modelVersion > _maxModelVersion) {
      throw Exception(
          "the loaded model has been created with a newer generator version $modelVersion, while the maximimum supported version is $_maxModelVersion. Please upgrade your toolchain/generator");
    }

    if (entities == null) throw Exception("entities is null");
    if (retiredEntityUids == null) throw Exception("retiredEntityUids is null");
    if (retiredIndexUids == null) throw Exception("retiredIndexUids is null");
    if (retiredPropertyUids == null) throw Exception("retiredPropertyUids is null");
    if (retiredRelationUids == null) throw Exception("retiredRelationUids is null");
    if (lastEntityId == null) throw Exception("lastEntityId is null");

    bool lastEntityIdFound = false;
    for (final e in entities) {
      if (e.model != this) {
        throw Exception("entity '${e.name}' with id ${e.id.toString()} has incorrect parent model reference");
      }
      e.validate();
      if (lastEntityId.id < e.id.id) {
        throw Exception(
            "lastEntityId ${lastEntityId.toString()} is lower than the one of entity '${e.name}' with id ${e.id.toString()}");
      }
      if (lastEntityId.id == e.id.id) {
        if (lastEntityId.uid != e.id.uid) {
          throw Exception(
              "lastEntityId ${lastEntityId.toString()} does not match entity '${e.name}' with id ${e.id.toString()}");
        }
        lastEntityIdFound = true;
      }
    }

    if (!lastEntityIdFound && !listContains(this.retiredEntityUids, lastEntityId.uid)) {
      throw Exception("lastEntityId ${lastEntityId.toString()} does not match any entity");
    }
  }

  Map<String, dynamic> toMap({bool forCodeGen = false}) {
    Map<String, dynamic> ret = {};
    if (!forCodeGen) {
      ret["_note1"] = notes[0];
      ret["_note2"] = notes[1];
      ret["_note3"] = notes[2];
    }
    ret["entities"] = entities.map((p) => p.toMap()).toList();
    ret["lastEntityId"] = lastEntityId.toString();
    ret["lastIndexId"] = lastIndexId.toString();
    ret["lastRelationId"] = lastRelationId.toString();
    ret["lastSequenceId"] = lastSequenceId.toString();
    ret["modelVersion"] = modelVersion;
    if (!forCodeGen) {
      ret["modelVersionParserMinimum"] = modelVersionParserMinimum;
      ret["retiredEntityUids"] = retiredEntityUids;
      ret["retiredIndexUids"] = retiredIndexUids;
      ret["retiredPropertyUids"] = retiredPropertyUids;
      ret["retiredRelationUids"] = retiredRelationUids;
      ret["version"] = version;
    }
    return ret;
  }

  ModelEntity findEntityByUid(int uid) {
    int idx = entities.indexWhere((e) => e.id.uid == uid);
    return idx == -1 ? null : entities[idx];
  }

  ModelEntity findEntityByName(String name) {
    final found = entities.where((e) => e.name.toLowerCase() == name.toLowerCase()).toList();
    if (found.isEmpty) return null;
    if (found.length >= 2) throw Exception("ambiguous entity name: $name; please specify a UID in its annotation");
    return found[0];
  }

  ModelEntity findSameEntity(ModelEntity other) {
    ModelEntity ret;
    if (other.id.uid != 0) ret = findEntityByUid(other.id.uid);
    if (ret == null) ret = findEntityByName(other.name);
    return ret;
  }

  ModelEntity addEntity(ModelEntity other) {
    ModelEntity ret = createEntity(other.name, other.id.uid);
    other.properties.forEach((p) => ret.addProperty(p));
    return ret;
  }

  ModelEntity createEntity(String name, [int uid = 0]) {
    int id = 1;
    if (entities.isNotEmpty) id = lastEntityId.id + 1;
    if (uid != 0 && containsUid(uid)) throw Exception("uid already exists: $uid");
    int uniqueUid = uid == 0 ? generateUid() : uid;

    var entity = ModelEntity(IdUid(id, uniqueUid), null, name, [], this);
    entities.add(entity);
    lastEntityId = entity.id;
    return entity;
  }

  void removeEntity(ModelEntity entity) {
    if (entity == null) throw Exception("entity == null");

    final foundEntity = findSameEntity(entity);
    if (foundEntity == null) {
      throw Exception("cannot remove entity '${entity.name}' with id ${entity.id.toString()}: not found");
    }
    entities = entities.where((p) => p != foundEntity).toList();
    retiredEntityUids.add(entity.id.uid);
    entity.properties.forEach((prop) => retiredPropertyUids.add(prop.id.uid));
  }

  int generateUid() {
    var rng = Random();
    for (int i = 0; i < 1000; ++i) {
      // Dart can only generate random numbers up to 1 << 32, so concat two of them and remove the upper bit to make the number non-negative
      int uid = rng.nextInt(1 << 32);
      uid |= rng.nextInt(1 << 32) << 32;
      uid &= ~(1 << 63);
      if (uid != 0 && !containsUid(uid)) return uid;
    }

    throw Exception("internal error: could not generate a unique UID");
  }

  bool containsUid(int uid) {
    if (lastEntityId.uid == uid) return true;
    if (lastIndexId.uid == uid) return true;
    if (lastRelationId.uid == uid) return true;
    if (lastSequenceId.uid == uid) return true;
    if (entities.indexWhere((e) => e.containsUid(uid)) != -1) return true;
    if (listContains(retiredEntityUids, uid)) return true;
    if (listContains(retiredIndexUids, uid)) return true;
    if (listContains(retiredPropertyUids, uid)) return true;
    if (listContains(retiredRelationUids, uid)) return true;
    return false;
  }
}
