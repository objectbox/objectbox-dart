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

  Entity.fromMap(Map<String, dynamic> data, this.model) {
    id = IdUid(data["id"]);
    lastPropertyId = IdUid(data["lastPropertyId"]);
    name = data["name"];
    properties = data["properties"].map<Property>((p) => Property.fromMap(p, this)).toList();
    validate();
  }

  void validate() {
    if (name == null || name.length == 0) throw Exception("name is not defined");
    if (properties == null) throw Exception("properties is null");
    if (model == null) throw Exception("model is null");

    var entity = this;
    bool lastPropertyIdFound = false;
    properties.forEach((p) {
      if (p.entity != entity)
        throw Exception("property '${p.name}' with id ${p.id.toString()} has incorrect parent entity reference");
      if (lastPropertyId.id < p.id.id)
        throw Exception(
            "lastPropertyId ${lastPropertyId.toString()} is lower than the one of property '${p.name}' with id ${p.id.toString()}");
      if (lastPropertyId.id == p.id.id) {
        if (lastPropertyId.uid != p.id.uid)
          throw Exception(
              "lastPropertyId ${lastPropertyId.toString()} does not match property '${p.name}' with id ${p.id.toString()}");
        lastPropertyIdFound = true;
      }
    });

    if (properties.length > 0 && !lastPropertyIdFound)
      throw Exception("lastPropertyId ${lastPropertyId.toString()} does not match any property");
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> ret = {};
    ret["id"] = id.toString();
    ret["lastPropertyId"] = lastPropertyId.toString();
    ret["name"] = name;
    ret["properties"] = properties.map((p) => p.toMap()).toList();
    return ret;
  }

  Property findPropertyByUid(int uid) {
    int idx = properties.indexWhere((p) => p.id.uid == uid);
    return idx == -1 ? null : properties[idx];
  }

  Property findPropertyByName(String name) {
    int idx = properties.indexWhere((p) => p.name.toLowerCase() == name.toLowerCase());
    return idx == -1 ? null : properties[idx];
  }

  Property createProperty() {
    int id = 1;
    if (properties.length > 0) id = lastPropertyId.id + 1;
    int uniqueUid = model.generateUid();

    var property = Property(IdUid.create(id, uniqueUid), null, 0, 0, this);
    properties.add(property);
    lastPropertyId = property.id;
    return property;
  }

  void removeProperty(Property property) {
    int idx = properties.indexWhere((p) => p == property);
    if (idx == -1)
      throw Exception("cannot remove property '${property.name}' with id ${property.id.toString()}: not found");
    properties = properties.where((p) => p != property).toList();
    model.retiredPropertyUids.add(property.id.uid);
  }

  bool containsUid(int searched) {
    if (id.uid == searched) return true;
    if (lastPropertyId.uid == searched) return true;
    if (properties.indexWhere((p) => p.containsUid(searched)) != -1) return true;
    return false;
  }
}