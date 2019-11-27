import '../util.dart';
import "iduid.dart";
import "modelinfo.dart";
import "modelproperty.dart";
import "package:objectbox/src/bindings/constants.dart";

/// ModelEntity describes an entity of a model and consists of instances of `ModelProperty` as well as an other entity
/// information: id, name and last property id.
class ModelEntity {
  IdUid id, lastPropertyId;
  String name;
  List<ModelProperty> properties;
  ModelProperty idProperty;
  ModelInfo _model;

  ModelInfo get model => (_model == null) ? throw Exception("model is null") : _model;

  ModelEntity(this.id, this.lastPropertyId, this.name, this.properties, this._model) {
    validate();
  }

  ModelEntity.fromMap(Map<String, dynamic> data, {ModelInfo model, bool check = true}) {
    _model = model;
    id = IdUid.fromString(data["id"]);
    lastPropertyId = IdUid.fromString(data["lastPropertyId"]);
    name = data["name"];
    properties = data["properties"].map<ModelProperty>((p) => ModelProperty.fromMap(p, this, check: check)).toList();
    if (check) validate();

    idProperty = properties.firstWhere((p) => (p.flags & OBXPropertyFlag.ID) != 0);
    if (check && idProperty == null) throw Exception("idProperty is null");
  }

  void validate() {
    if (name == null || name.isEmpty) throw Exception("name is not defined");
    if (properties == null) throw Exception("properties is null");

    if (properties.isEmpty) {
      if (lastPropertyId != null) throw Exception("lastPropertyId is not null although there are no properties");
    } else {
      if (lastPropertyId == null) throw Exception("lastPropertyId is null");

      bool lastPropertyIdFound = false;
      for (final p in properties) {
        if (p.entity != this) {
          throw Exception("property '${p.name}' with id ${p.id.toString()} has incorrect parent entity reference");
        }
        p.validate();
        if (lastPropertyId.id < p.id.id) {
          throw Exception(
              "lastPropertyId ${lastPropertyId.toString()} is lower than the one of property '${p.name}' with id ${p.id.toString()}");
        }
        if (lastPropertyId.id == p.id.id) {
          if (lastPropertyId.uid != p.id.uid) {
            throw Exception(
                "lastPropertyId ${lastPropertyId.toString()} does not match property '${p.name}' with id ${p.id.toString()}");
          }
          lastPropertyIdFound = true;
        }
      }

      if (!lastPropertyIdFound && !listContains(model.retiredPropertyUids, lastPropertyId.uid)) {
        throw Exception("lastPropertyId ${lastPropertyId.toString()} does not match any property");
      }
    }
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> ret = {};
    ret["id"] = id.toString();
    ret["lastPropertyId"] = lastPropertyId == null ? null : lastPropertyId.toString();
    ret["name"] = name;
    ret["properties"] = properties.map((p) => p.toMap()).toList();
    return ret;
  }

  ModelProperty findPropertyByUid(int uid) {
    int idx = properties.indexWhere((p) => p.id.uid == uid);
    return idx == -1 ? null : properties[idx];
  }

  ModelProperty findPropertyByName(String name) {
    final found = properties.where((p) => p.name.toLowerCase() == name.toLowerCase()).toList();
    if (found.isEmpty) return null;
    if (found.length >= 2) throw Exception("ambiguous property name: $name; please specify a UID in its annotation");
    return found[0];
  }

  ModelProperty findSameProperty(ModelProperty other) {
    ModelProperty ret;
    if (other.id.uid != 0) ret = findPropertyByUid(other.id.uid);
    if (ret == null) ret = findPropertyByName(other.name);
    return ret;
  }

  ModelProperty createProperty(String name, [int uid = 0]) {
    int id = 1;
    if (properties.isNotEmpty) id = lastPropertyId.id + 1;
    if (uid != 0 && model.containsUid(uid)) throw Exception("uid already exists: $uid");
    int uniqueUid = uid == 0 ? model.generateUid() : uid;

    var property = ModelProperty(IdUid(id, uniqueUid), name, 0, 0, this);
    properties.add(property);
    lastPropertyId = property.id;
    return property;
  }

  ModelProperty addProperty(ModelProperty prop) {
    ModelProperty ret = createProperty(prop.name, prop.id.uid);
    ret.type = prop.type;
    ret.flags = prop.flags;
    return ret;
  }

  void removeProperty(ModelProperty prop) {
    if (prop == null) throw Exception("prop == null");
    ModelProperty foundProp = findSameProperty(prop);
    if (foundProp == null) {
      throw Exception("cannot remove property '${prop.name}' with id ${prop.id.toString()}: not found");
    }
    properties = properties.where((p) => p != foundProp).toList();
    model.retiredPropertyUids.add(prop.id.uid);
  }

  bool containsUid(int searched) {
    if (id.uid == searched) return true;
    if (lastPropertyId != null && lastPropertyId.uid == searched) return true;
    if (properties.indexWhere((p) => p.containsUid(searched)) != -1) return true;
    return false;
  }
}
