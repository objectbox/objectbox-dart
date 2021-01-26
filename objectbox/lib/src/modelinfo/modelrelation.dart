import 'iduid.dart';

/// ModelRelation describes a standalone relation
class ModelRelation {
  IdUid id;

  /*late*/
  String _name;

  /*late*/
  IdUid _targetId;

  String /*?*/ _targetName;

  String get name => _name;

  set name(String /*?*/ value) {
    if (value == null || value.isEmpty) {
      throw Exception('name must not be null or an empty string');
    }
    _name = value /*!*/;
  }

  IdUid get targetId => _targetId;

  set targetId(IdUid /*?*/ value) {
    if (value != null) {
      if (value.id == 0 || value.uid == 0) {
        throw Exception('targetId must contain valid ID & UID');
      }
    }
    _targetId = value /*!*/;
  }

  String get targetName => _targetName;

  set targetName(String /*?*/ value) {
    if (value == null || value.isEmpty) {
      throw Exception('targetName must not be null or an empty string');
    }
    _targetName = value /*!*/;
  }

  ModelRelation(this.id, String /*?*/ name,
      {String /*?*/ targetId, String /*?*/ targetName}) {
    this.name = name;
    if (targetId != null) this.targetId = IdUid.fromString(targetId);
    if (targetName != null) this.targetName = targetName;
  }

  ModelRelation.fromMap(Map<String, dynamic> data)
      : this(IdUid.fromString(data['id']), data['name'],
            targetId: data['targetId'], targetName: data['targetName']);

  Map<String, dynamic> toMap({bool forModelJson = false}) {
    final ret = <String, dynamic>{};
    ret['id'] = id.toString();
    ret['name'] = name;
    if (targetId != null) ret['targetId'] = targetId.toString();
    if (!forModelJson && targetName != null) ret['targetName'] = targetName;
    return ret;
  }

  @override
  String toString() =>
      'standalone relation ${name}(${id}) relTarget: ${targetName}(${targetId})';
}
