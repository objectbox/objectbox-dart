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
}
