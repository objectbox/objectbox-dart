import 'enums.dart';
import 'iduid.dart';
import 'modelbacklink.dart';
import 'modelinfo.dart';
import 'modelproperty.dart';
import 'modelrelation.dart';

// ignore_for_file: public_member_api_docs

/// ModelEntity describes an entity of a model.
class ModelEntity {
  IdUid id;

  late String _name;
  IdUid lastPropertyId = IdUid.empty();
  int _flags = 0;
  final _properties = <ModelProperty>[];
  final _relations = <ModelRelation>[];
  final _backlinks = <ModelBacklink>[];
  ModelProperty? _idProperty;
  final ModelInfo? _model;

  late List<String> constructorParams;

  // whether the library this entity is defined in uses null safety
  bool nullSafetyEnabled = true;

  String get name => _name;

  set name(String? value) {
    if (value == null || value.isEmpty) {
      throw ArgumentError('name must not be null or an empty string');
    }
    _name = value;
  }

  int get flags => _flags;

  set flags(int? value) {
    if (value == null || value < 0) {
      throw ArgumentError('flags must be defined and may not be < 0');
    }
    _flags = value;
  }

  ModelProperty get idProperty {
    _idProperty ??= _properties.singleWhere(
        (ModelProperty prop) => prop.hasFlag(OBXPropertyFlags.ID),
        orElse: (() => throw StateError('idProperty is null')));
    return _idProperty!;
  }

  ModelInfo get model =>
      (_model == null) ? throw StateError('model is null') : _model!;

  List<ModelProperty> get properties => _properties;

  List<ModelRelation> get relations => _relations;

  List<ModelBacklink> get backlinks => _backlinks;

  ModelEntity(this.id, String? name, this._model) {
    this.name = name;
    validate();
  }

  ModelEntity.fromMap(Map<String, dynamic> data,
      {ModelInfo? model, bool check = true})
      : _model = model,
        id = IdUid.fromString(data['id'] as String?),
        lastPropertyId = IdUid.fromString(data['lastPropertyId'] as String?),
        nullSafetyEnabled = data['nullSafetyEnabled'] as bool? ?? true {
    name = data['name'] as String?;
    flags = data['flags'] as int? ?? 0;

    ArgumentError.checkNotNull(data['properties'], "data['properties']");
    for (final p in data['properties']) {
      _properties.add(ModelProperty.fromMap(p as Map<String, dynamic>, this));
    }

    if (data['relations'] != null) {
      for (final p in data['relations']) {
        _relations.add(ModelRelation.fromMap(p as Map<String, dynamic>));
      }
    }

    if (data['backlinks'] != null) {
      for (final p in data['backlinks']) {
        _backlinks.add(ModelBacklink.fromMap(p as Map<String, dynamic>));
      }
    }

    if (data['constructorParams'] != null) {
      constructorParams = (data['constructorParams'] as List<dynamic>)
          .map((dynamic e) => e as String)
          .toList(growable: false);
    }

    if (check) validate();

    _idProperty =
        properties.singleWhere((p) => (p.flags & OBXPropertyFlags.ID) != 0);
  }

  void validate() {
    if (properties.isEmpty) {
      if (!lastPropertyId.isEmpty) {
        throw StateError(
            'lastPropertyId is not empty although there are no properties');
      }
    } else {
      var lastPropertyIdFound = false;
      for (final p in properties) {
        if (p.entity != this) {
          throw StateError(
              "property '${p.name}' with id ${p.id} has incorrect parent entity reference");
        }
        if (lastPropertyId.id < p.id.id) {
          throw StateError(
              "lastPropertyId $lastPropertyId is lower than the one of property '${p.name}' with id ${p.id}");
        }
        if (lastPropertyId.id == p.id.id) {
          if (lastPropertyId.uid != p.id.uid) {
            throw StateError(
                "lastPropertyId $lastPropertyId does not match property '${p.name}' with id ${p.id}");
          }
          lastPropertyIdFound = true;
        }
      }

      if (!lastPropertyIdFound &&
          !model.retiredPropertyUids.contains(lastPropertyId.uid)) {
        throw StateError(
            'lastPropertyId $lastPropertyId does not match any property');
      }
    }

    for (final r in relations) {
      if (r.targetId.isEmpty) {
        throw StateError(
            "relation '${r.name}' with id ${r.id} has incorrect target entity reference");
      }
    }
  }

  Map<String, dynamic> toMap({bool forModelJson = false}) {
    final ret = <String, dynamic>{};
    ret['id'] = id.toString();
    ret['lastPropertyId'] = lastPropertyId.toString();
    ret['name'] = name;
    if (flags != 0) ret['flags'] = flags;
    ret['properties'] =
        properties.map((p) => p.toMap(forModelJson: forModelJson)).toList();
    ret['relations'] =
        relations.map((r) => r.toMap(forModelJson: forModelJson)).toList();
    if (!forModelJson) {
      ret['backlinks'] = backlinks.map((r) => r.toMap()).toList();
      ret['constructorParams'] = constructorParams;
      ret['nullSafetyEnabled'] = nullSafetyEnabled;
    }
    return ret;
  }

  ModelProperty? _findPropertyByUid(int uid) {
    final idx = properties.indexWhere((p) => p.id.uid == uid);
    return idx == -1 ? null : properties[idx];
  }

  ModelProperty? findPropertyByName(String name) {
    final found = properties
        .where((p) => p.name.toLowerCase() == name.toLowerCase())
        .toList();
    if (found.isEmpty) return null;
    if (found.length >= 2) {
      throw StateError(
          'ambiguous property name: $name; please specify a UID in its annotation');
    }
    return found[0];
  }

  ModelProperty? findSameProperty(ModelProperty other) {
    ModelProperty? ret;
    if (other.id.uid != 0) ret = _findPropertyByUid(other.id.uid);
    return ret ?? findPropertyByName(other.name);
  }

  ModelProperty createProperty(String name, [int uid = 0]) {
    final id = lastPropertyId.id + 1;
    if (uid != 0 && model.containsUid(uid)) {
      throw StateError('uid already exists: $uid');
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
      throw StateError(
          "cannot remove property '${prop.name}' with id ${prop.id}: not found");
    }
    _properties.remove(foundProp);
    model.retiredPropertyUids.add(prop.id.uid);

    if (prop.indexId != null) {
      model.retiredIndexUids.add(prop.indexId!.uid);
    }
  }

  ModelRelation? _findRelationByUid(int uid) {
    final idx = relations.indexWhere((p) => p.id.uid == uid);
    return idx == -1 ? null : relations[idx];
  }

  ModelRelation? _findRelationByName(String name) {
    final found = relations
        .where((p) => p.name.toLowerCase() == name.toLowerCase())
        .toList();
    if (found.isEmpty) return null;
    if (found.length >= 2) {
      throw StateError(
          'ambiguous relation name: $name; please specify a UID in its annotation');
    }
    return found[0];
  }

  ModelRelation? findSameRelation(ModelRelation other) {
    ModelRelation? ret;
    if (other.id.uid != 0) ret = _findRelationByUid(other.id.uid);
    return ret ?? _findRelationByName(other.name);
  }

  ModelRelation createRelation(String name, [int uid = 0]) {
    final id = model.lastRelationId.id + 1;
    if (uid != 0 && model.containsUid(uid)) {
      throw StateError('uid already exists: $uid');
    }
    final uniqueUid = uid == 0 ? model.generateUid() : uid;

    final relation = ModelRelation(IdUid(id, uniqueUid), name);
    relations.add(relation);
    model.lastRelationId = relation.id;

    return relation;
  }

  void removeRelation(ModelRelation rel) {
    final foundRel = findSameRelation(rel);
    if (foundRel == null) {
      throw StateError(
          "cannot remove relation '${rel.name}' with id ${rel.id}: not found");
    }
    _relations.remove(foundRel);
    model.retiredRelationUids.add(rel.id.uid);
  }

  bool containsUid(int searched) {
    if (id.uid == searched) return true;
    if (lastPropertyId.uid == searched) return true;
    if (properties.indexWhere((p) => p.id.uid == searched) != -1) {
      return true;
    }
    if (relations.indexWhere((p) => p.id.uid == searched) != -1) {
      return true;
    }
    return false;
  }

  bool hasFlag(int flag) => (flags & flag) == flag;

  @override
  String toString() {
    var result = 'entity $name($id)';
    result += ' sync:${hasFlag(OBXEntityFlags.SYNC_ENABLED) ? 'ON' : 'OFF'}';
    return result;
  }
}
