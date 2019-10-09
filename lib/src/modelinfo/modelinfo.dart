import "dart:math";

import "modelentity.dart";
import "iduid.dart";

const _minModelVersion = 5;
const _maxModelVersion = 5;

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

  ModelInfo.fromMap(Map<String, dynamic> data) {
    entities = data["entities"].map<ModelEntity>((e) => ModelEntity.fromMap(e, this)).toList();
    lastEntityId = IdUid(data["lastEntityId"]);
    lastIndexId = IdUid(data["lastIndexId"]);
    lastRelationId = IdUid(data["lastRelationId"]);
    lastSequenceId = IdUid(data["lastSequenceId"]);
    modelVersion = data["modelVersion"];
    modelVersionParserMinimum = data["modelVersionParserMinimum"];
    retiredEntityUids = data["retiredEntityUids"].map<int>((x) => x as int).toList();
    retiredIndexUids = data["retiredIndexUids"].map<int>((x) => x as int).toList();
    retiredPropertyUids = data["retiredPropertyUids"].map<int>((x) => x as int).toList();
    retiredRelationUids = data["retiredRelationUids"].map<int>((x) => x as int).toList();
    version = data["version"];
    validate();
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

    var model = this;
    bool lastEntityIdFound = false;
    entities.forEach((e) {
      if (e.model != model) {
        throw Exception("entity '${e.name}' with id ${e.id.toString()} has incorrect parent model reference");
      }
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
    });

    if (entities.length > 0 && !lastEntityIdFound) {
      throw Exception("lastEntityId ${lastEntityId.toString()} does not match any entity");
    }
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> ret = {};
    ret["_note1"] = notes[0];
    ret["_note2"] = notes[1];
    ret["_note3"] = notes[2];
    ret["entities"] = entities.map((p) => p.toMap()).toList();
    ret["lastEntityId"] = lastEntityId.toString();
    ret["lastIndexId"] = lastIndexId.toString();
    ret["lastRelationId"] = lastRelationId.toString();
    ret["lastSequenceId"] = lastSequenceId.toString();
    ret["modelVersion"] = modelVersion;
    ret["modelVersionParserMinimum"] = modelVersionParserMinimum;
    ret["retiredEntityUids"] = retiredEntityUids;
    ret["retiredIndexUids"] = retiredIndexUids;
    ret["retiredPropertyUids"] = retiredPropertyUids;
    ret["retiredRelationUids"] = retiredRelationUids;
    ret["version"] = version;
    return ret;
  }

  ModelEntity findEntityByUid(int uid) {
    int idx = entities.indexWhere((e) => e.id.uid == uid);
    return idx == -1 ? null : entities[idx];
  }

  ModelEntity findEntityByName(String name) {
    final found = entities.where((e) => e.name.toLowerCase() == name.toLowerCase()).toList();
    if (found.length == 0) return null;
    if (found.length >= 2) throw Exception("ambiguous entity name: $name; please specify a UID in its annotation");
    return found[0];
  }

  ModelEntity findSameEntity(ModelEntity other) {
    ModelEntity ret;
    if (other.id.uid != 0) ret = findEntityByUid(other.id.uid);
    if (ret == null) ret = findEntityByName(other.name);
    return ret;
  }

  ModelEntity createCopiedEntity(ModelEntity other) {
    ModelEntity ret = createEntity(other.name, other.id.uid);
    other.properties.forEach((p) => ret.createCopiedProperty(p));
    return ret;
  }

  ModelEntity createEntity(String name, [int uid = 0]) {
    int id = 1;
    if (entities.length > 0) id = lastEntityId.id + 1;
    if (uid != 0 && containsUid(uid)) throw Exception("uid already exists: $uid");
    int uniqueUid = uid == 0 ? generateUid() : uid;

    var entity = new ModelEntity(IdUid.create(id, uniqueUid), null, name, [], this);
    entities.add(entity);
    lastEntityId = entity.id;
    return entity;
  }

  int generateUid() {
    var rng = new Random();
    for (int i = 0; i < 1000; ++i) {
      // Dart can only generate random numbers up to 1 << 32, so concat two of them and remove the upper bit to make the number non-negative
      int uid = rng.nextInt(1 << 32);
      uid |= rng.nextInt(1 << 32) << 32;
      uid &= ~(1 << 63);
      if (uid != 0 && !containsUid(uid)) return uid;
    }

    throw Exception("internal error: could not generate a unique UID");
  }

  bool containsUid(int searched) {
    if (lastEntityId.uid == searched) return true;
    if (lastIndexId.uid == searched) return true;
    if (lastRelationId.uid == searched) return true;
    if (lastSequenceId.uid == searched) return true;
    if (entities.indexWhere((e) => e.containsUid(searched)) != -1) return true;
    if (retiredEntityUids.indexWhere((x) => x == searched) != -1) return true;
    if (retiredIndexUids.indexWhere((x) => x == searched) != -1) return true;
    if (retiredPropertyUids.indexWhere((x) => x == searched) != -1) return true;
    if (retiredRelationUids.indexWhere((x) => x == searched) != -1) return true;
    return false;
  }
}
