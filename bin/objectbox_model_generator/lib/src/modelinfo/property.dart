import "iduid.dart";

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
