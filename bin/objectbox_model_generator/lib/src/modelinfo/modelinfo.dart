import "dart:math";

import "entity.dart";
import "iduid.dart";

const ModelVersion = 5;
const minModelVersion = 5;
const maxModelVersion = ModelVersion;

class ModelInfo {
  static const notes = [
    "KEEP THIS FILE! Check it into a version control system (VCS) like git.",
    "ObjectBox manages crucial IDs for your object model. See docs for details.",
    "If you have VCS merge conflicts, you must resolve them according to ObjectBox docs.",
  ];

  List<Entity> entities;
  IdUid lastEntityId;
  List<int> retiredEntityUids, retiredPropertyUids;
  int modelVersion, minimumParserVersion, version;

  ModelInfo.createDefault()
      : entities = [],
        retiredEntityUids = [],
        retiredPropertyUids = [],
        modelVersion = maxModelVersion,
        minimumParserVersion = maxModelVersion,
        version = 1;

  ModelInfo.fromMap(Map<String, dynamic> data) {
    entities = data["entities"].map<Entity>((e) => Entity.fromMap(e, this)).toList();
    lastEntityId = IdUid(data["lastEntityId"]);
    retiredEntityUids = data["retiredEntityUids"].map<int>((x) => x as int).toList();
    retiredPropertyUids = data["retiredPropertyUids"].map<int>((x) => x as int).toList();
    modelVersion = data["modelVersion"];
    minimumParserVersion = data["minimumParserVersion"];
    version = data["version"];
    validate();
  }

  void validate() {
    if (modelVersion < minModelVersion)
      throw Exception(
          "the loaded model is too old: version $modelVersion while the minimum supported is $minModelVersion, consider upgrading with an older generator or manually");
    if (modelVersion > maxModelVersion)
      throw Exception(
          "the loaded model has been created with a newer generator version $modelVersion, while the maximimum supported version is $maxModelVersion. Please upgrade your toolchain/generator");

    if (entities == null) throw Exception("entities is null");
    if (retiredEntityUids == null) throw Exception("retiredEntityUids is null");
    if (retiredPropertyUids == null) throw Exception("retiredPropertyUids is null");

    var model = this;
    bool lastEntityIdFound = false;
    entities.forEach((e) {
      if (e.model != model)
        throw Exception("entity '${e.name}' with id ${e.id.toString()} has incorrect parent model reference");
      if (lastEntityId.id < e.id.id)
        throw Exception(
            "lastEntityId ${lastEntityId.toString()} is lower than the one of entity '${e.name}' with id ${e.id.toString()}");
      if (lastEntityId.id == e.id.id) {
        if (lastEntityId.uid != e.id.uid)
          throw Exception(
              "lastEntityId ${lastEntityId.toString()} does not match entity '${e.name}' with id ${e.id.toString()}");
        lastEntityIdFound = true;
      }
    });

    if (entities.length > 0 && !lastEntityIdFound)
      throw Exception("lastEntityId ${lastEntityId.toString()} does not match any entity");
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> ret = {};
    ret["_note1"] = notes[0];
    ret["_note2"] = notes[1];
    ret["_note3"] = notes[2];
    ret["entities"] = entities.map((p) => p.toMap()).toList();
    ret["lastEntityId"] = lastEntityId.toString();
    ret["retiredEntityUids"] = retiredEntityUids;
    ret["retiredPropertyUids"] = retiredPropertyUids;
    ret["modelVersion"] = modelVersion;
    ret["minimumParserVersion"] = minimumParserVersion;
    ret["version"] = version;
    return ret;
  }

  Entity findEntityByUid(int uid) {
    int idx = entities.indexWhere((e) => e.id.uid == uid);
    return idx == -1 ? null : entities[idx];
  }

  Entity findEntityByName(String name) {
    int idx = entities.indexWhere((e) => e.name.toLowerCase() == name.toLowerCase());
    return idx == -1 ? null : entities[idx];
  }

  Entity createEntity(String name) {
    int id = 1;
    if (entities.length > 0) id = lastEntityId.id + 1;
    int uniqueUid = generateUid();

    var entity = new Entity(IdUid.create(id, uniqueUid), null, name, [], this);
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
      uid &= ~(1 << 64);
      if (uid != 0 && !containsUid(uid)) return uid;
    }

    throw Exception("internal error: could not generate a unique UID");
  }

  bool containsUid(int searched) {
    if (lastEntityId.uid == searched) return true;
    if (retiredEntityUids.indexWhere((x) => x == searched) != -1) return true;
    if (retiredPropertyUids.indexWhere((x) => x == searched) != -1) return true;
    if (entities.indexWhere((e) => e.containsUid(searched)) != -1) return true;
    return false;
  }
}
