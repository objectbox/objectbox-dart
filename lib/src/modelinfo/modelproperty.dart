import 'modelentity.dart';
import 'iduid.dart';

/// ModelProperty describes a single property of an entity, i.e. its id, name, type and flags.
class ModelProperty {
  IdUid id;
  /*late*/ String _name;
  /*late*/ int _type, _flags;
  ModelEntity /*?*/ entity;

  String get name => _name;

  set name(String /*?*/ value) {
    if (value == null || value.isEmpty) {
      throw Exception('name must not be null or an empty string');
    }
    _name = value /*!*/;
  }

  int get type => _type;

  set type(int /*?*/ value) {
    if (value == null || value < 0) {
      throw Exception('type must be defined and may not be < 0');
    }
    _type = value /*!*/;
  }

  int get flags => _flags;

  set flags(int /*?*/ value) {
    if (value == null || value < 0) {
      throw Exception('flags must be defined and may not be < 0');
    }
    _flags = value /*!*/;
  }

  ModelProperty(this.id, String /*?*/ name, int /*?*/ type, int /*?*/ flags,
      this.entity) {
    this.name = name;
    this.type = type;
    this.flags = flags;
  }

  ModelProperty.fromMap(Map<String, dynamic> data, ModelEntity /*?*/ entity)
      : this(IdUid.fromString(data['id']), data['name'], data['type'],
            data['flags'] ?? 0, entity);

  Map<String, dynamic> toMap() {
    final ret = <String, dynamic>{};
    ret['id'] = id.toString();
    ret['name'] = name;
    ret['type'] = type;
    if (flags != 0) ret['flags'] = flags;
    return ret;
  }

  bool containsUid(int searched) {
    return id.uid == searched;
  }

  bool hasFlag(int flag) {
    return (flags & flag) == flag;
  }
}
