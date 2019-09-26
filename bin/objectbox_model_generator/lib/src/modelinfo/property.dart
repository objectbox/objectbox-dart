import "entity.dart";
import "iduid.dart";

class Property {
  IdUid id;
  String name;
  int type, flags;
  Entity entity;

  Property(this.id, this.name, this.type, this.flags, this.entity) {
    validate();
  }

  Property.fromMap(Map<String, dynamic> data, this.entity) {
    id = IdUid(data["id"]);
    name = data["name"];
    type = data["type"];
    flags = data.containsKey("flags") ? data["flags"] : 0;
    validate();
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
