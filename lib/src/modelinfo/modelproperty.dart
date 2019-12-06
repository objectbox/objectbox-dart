import "modelentity.dart";
import "iduid.dart";

/// ModelProperty describes a single property of an entity, i.e. its id, name, type and flags.
class ModelProperty {
  IdUid id;
  String name;
  int type, flags;
  ModelEntity entity;

  ModelProperty(this.id, this.name, this.type, this.flags, this.entity) {
    validate();
  }

  ModelProperty.fromMap(Map<String, dynamic> data, this.entity, {bool check = true}) {
    id = IdUid.fromString(data["id"]);
    name = data["name"];
    type = data["type"];
    flags = data.containsKey("flags") ? data["flags"] : 0;
    if (check) validate();
  }

  void validate() {
    if (type == null || type < 0) throw Exception("type must be defined and may not be < 0");
    if (flags == null || flags < 0) throw Exception("flags must be defined and may not be < 0");
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> ret = {};
    ret["id"] = id.toString();
    ret["name"] = name;
    ret["type"] = type;
    if (flags != 0) ret["flags"] = flags;
    return ret;
  }

  bool containsUid(int searched) {
    return id.uid == searched;
  }
}
