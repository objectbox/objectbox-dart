import '../bindings/bindings.dart';
import '../util.dart';
import 'iduid.dart';
import 'modelinfo.dart';
import 'modelproperty.dart';

/// ModelEntity describes an entity of a model and consists of instances of `ModelProperty` as well as an other entity
/// information: id, name and last property id.
class ModelEntity {
  IdUid id;
  /*late*/ String _name;
  IdUid lastPropertyId = IdUid.empty();
  int _flags = 0;
  final _properties = <ModelProperty>[];
  ModelProperty /*?*/ _idProperty;
  final ModelInfo /*?*/ _model;

  String get name => _name;

  set name(String /*?*/ value) {
    if (value == null || value.isEmpty) {
      throw Exception('name must not be null or an empty string');
    }
    _name = value /*!*/;
  }

  int get flags => _flags;

  set flags(int /*?*/ value) {
    if (value == null || value < 0) {
      throw Exception('flags must be defined and may not be < 0');
    }
    _flags = value /*!*/;
  }

  ModelProperty get idProperty => (_idProperty == null)
      ? throw Exception('idProperty is null')
      : _idProperty /*!*/;

  ModelInfo get model =>
      (_model == null) ? throw Exception('model is null') : _model /*!*/;

  List<ModelProperty> get properties => _properties;

  ModelEntity(this.id, String /*?*/ name, this._model) {
    this.name = name;
    validate();
  }

  ModelEntity.fromMap(Map<String, dynamic> data,
      {ModelInfo /*?*/ model, bool check = true})
      : _model = model,
        id = IdUid.fromString(data['id']),
        lastPropertyId = IdUid.fromString(data['lastPropertyId']) {
    name = data['name'];
    flags = data['flags'] ?? 0;

    if (data['properties'] == null) throw Exception('properties is null');
    for (final p in data['properties']) {
      _properties.add(ModelProperty.fromMap(p, this));
    }

    if (check) validate();

    _idProperty =
        properties.firstWhere((p) => (p.flags & OBXPropertyFlags.ID) != 0);
    if (check && idProperty == null) throw Exception('idProperty is null');
  }

  void validate() {
    if (properties.isEmpty) {
      if (!lastPropertyId.isEmpty) {
        throw Exception(
            'lastPropertyId is not empty although there are no properties');
      }
    } else {
      var lastPropertyIdFound = false;
      for (final p in properties) {
        if (p.entity != this) {
          throw Exception(
              "property '${p.name}' with id ${p.id.toString()} has incorrect parent entity reference");
        }
        if (lastPropertyId /*!*/ .id < p.id.id) {
          throw Exception(
              "lastPropertyId ${lastPropertyId.toString()} is lower than the one of property '${p.name}' with id ${p.id.toString()}");
        }
        if (lastPropertyId /*!*/ .id == p.id.id) {
          if (lastPropertyId /*!*/ .uid != p.id.uid) {
            throw Exception(
                "lastPropertyId ${lastPropertyId.toString()} does not match property '${p.name}' with id ${p.id.toString()}");
          }
          lastPropertyIdFound = true;
        }
      }

      if (!lastPropertyIdFound &&
          !listContains(model.retiredPropertyUids, lastPropertyId /*!*/ .uid)) {
        throw Exception(
            'lastPropertyId ${lastPropertyId.toString()} does not match any property');
      }
    }
  }

  Map<String, dynamic> toMap() {
    final ret = <String, dynamic>{};
    ret['id'] = id.toString();
    ret['lastPropertyId'] = lastPropertyId.toString();
    ret['name'] = name;
    if (flags != 0) ret['flags'] = flags;
    ret['properties'] = properties.map((p) => p.toMap()).toList();
    return ret;
  }

  ModelProperty /*?*/ _findPropertyByUid(int uid) {
    final idx = properties.indexWhere((p) => p.id.uid == uid);
    return idx == -1 ? null : properties[idx];
  }

  ModelProperty /*?*/ _findPropertyByName(String name) {
    final found = properties
        .where((p) => p.name.toLowerCase() == name.toLowerCase())
        .toList();
    if (found.isEmpty) return null;
    if (found.length >= 2) {
      throw Exception(
          'ambiguous property name: $name; please specify a UID in its annotation');
    }
    return found[0];
  }

  ModelProperty /*?*/ findSameProperty(ModelProperty other) {
    ModelProperty /*?*/ ret;
    if (other.id.uid != 0) ret = _findPropertyByUid(other.id.uid);
    return ret ??= _findPropertyByName(other.name);
  }

  ModelProperty createProperty(String name, [int uid = 0]) {
    var id = 1;
    if (properties.isNotEmpty) id = lastPropertyId.id + 1;
    if (uid != 0 && model.containsUid(uid)) {
      throw Exception('uid already exists: $uid');
    }
    final uniqueUid = uid == 0 ? model.generateUid() : uid;

    final property = ModelProperty(IdUid(id, uniqueUid), name, 0, entity: this);
    properties.add(property);
    lastPropertyId = property.id;

    return property;
  }

  void removeProperty(ModelProperty prop) {
    final foundProp = findSameProperty(prop);
    if (foundProp == null) {
      throw Exception(
          "cannot remove property '${prop.name}' with id ${prop.id.toString()}: not found");
    }
    _properties.remove(foundProp);
    model.retiredPropertyUids.add(prop.id.uid);

    if (prop.indexId != null) {
      model.retiredIndexUids.add(prop.indexId.uid);
    }
  }

  bool containsUid(int searched) {
    if (id.uid == searched) return true;
    if (lastPropertyId.uid == searched) return true;
    if (properties.indexWhere((p) => p.containsUid(searched)) != -1) {
      return true;
    }
    return false;
  }

  bool hasFlag(int flag) {
    return (flags & flag) == flag;
  }

  @override
  String toString() {
    var result = 'entity ${name}(${id})';
    result += ' sync:${hasFlag(OBXEntityFlags.SYNC_ENABLED) ? 'ON' : 'OFF'}';
    return result;
  }
}
