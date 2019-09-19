import "iduid.dart";
import "modelinfo.dart";
import "property.dart";

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

  /*void createProperty() {
    int id;
    if (properties.length > 0) id = lastPropertyId.id + 1;

    //int uniqueUid =
  }*/

  Map<String, dynamic> toMap() {
    Map<String, dynamic> ret = {};
    ret["id"] = id.toString();
    ret["lastPropertyId"] = lastPropertyId.toString();
    ret["name"] = name;
    ret["properties"] = properties.map((p) => p.toMap()).toList();
    return ret;
  }
}
