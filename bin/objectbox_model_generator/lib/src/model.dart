class IdUid {
  int id, uid;

  IdUid(String str) {
    var spl = str.split(":");
    if (spl.length != 2) throw Exception("IdUid has invalid format, too many columns: $str");
    id = int.parse(spl[0]); // TODO: check integer bounds
    uid = int.parse(spl[1]);
    validate();
  }

  IdUid.create(this.id, this.uid) {
    validate();
  }

  IdUid.empty()
      : this.id = 0,
        this.uid = 0;

  void validate() {
    if (id <= 0) throw Exception("id may not be <= 0");
    if (uid <= 0) throw Exception("uid may not be <= 0");
  }

  String toString() => "$id:$uid";
}

class Property {
  IdUid id;
  String name;
  int type, flags;

  Property(this.id, this.name, this.type, this.flags) {
    validate();
  }

  Property.fromMap(Map<String, dynamic> data) {
    id = IdUid(data["id"]);
    name = data["name"];
    type = data["type"];
    flags = data["flags"];
    validate();
  }

  void validate() {
    if (name.length == 0) throw Exception("name is undefined");
    if (type == null || type < 0) throw Exception("type must be defined and may not be < 0");
    if (flags == null || flags < 0) throw Exception("flags must be defined and may not be < 0");
  }

  bool containsUid(int searched) {
    return id.uid == searched;
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> ret = {};
    ret["id"] = id.toString();
    ret["name"] = name;
    ret["type"] = type;
    ret["flags"] = flags;
    return ret;
  }
}

class Entity {
  IdUid id, lastPropertyId;
  String name;
  List<Property> properties;
  ModelInfo model;

  Entity(this.id, this.lastPropertyId, this.name, this.properties, this.model) {
    validate();
  }

  Entity.fromMap(Map<String, dynamic> data, ModelInfo parentModel) {
    id = IdUid(data["id"]);
    lastPropertyId = IdUid(data["lastPropertyId"]);
    name = data["name"];
    properties = data["properties"].map<Property>((p) => Property.fromMap(p)).toList();
    model = parentModel;
    validate();
  }

  void validate() {
    if (name.length == 0) throw Exception("name is undefined");
    if (properties == null) throw Exception("properties is null");
    if (model == null) throw Exception("model is null");
  }

  Property findPropertyByUid(int uid) {
    int idx = properties.indexWhere((p) => p.id.uid == uid);
    return idx == -1 ? null : properties[idx];
  }

  Property findPropertyByName(String name) {
    int idx = properties.indexWhere((p) => p.name.toLowerCase() == name.toLowerCase());
    return idx == -1 ? null : properties[idx];
  }

  void createProperty() {
    int id;
    if (properties.length > 0) id = lastPropertyId.id + 1;

    //int uniqueUid =
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> ret = {};
    ret["id"] = id.toString();
    ret["lastPropertyId"] = lastPropertyId.toString();
    ret["name"] = name;
    ret["properties"] = properties.map((p) => p.toMap()).toList();
    return ret;
  }
}

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
