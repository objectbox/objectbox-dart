// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test.dart';

// **************************************************************************
// EntityGenerator
// **************************************************************************

Map<String, Map<String, dynamic>> _allOBXModels = null;

void _loadOBXModels() {
  if (FileSystemEntity.typeSync("objectbox-models.json") ==
      FileSystemEntityType.notFound)
    throw Exception("objectbox-models.json not found");

  _allOBXModels = {};
  List<dynamic> models =
      json.decode(new File("objectbox-models.json").readAsStringSync());
  List<Map<String, dynamic>> modelsTyped =
      models.map<Map<String, dynamic>>((x) => x).toList();
  modelsTyped.forEach((v) => _allOBXModels[v["entity"]["name"]] = v);
}

Map<String, dynamic> _getOBXModel(String entityName) {
  if (_allOBXModels == null) _loadOBXModels();
  if (!_allOBXModels.containsKey(entityName))
    throw Exception("entity missing in objectbox-models.json: $entityName");
  return _allOBXModels[entityName];
}

Map<String, dynamic> _TestEntity_OBXModelGetter() {
  return _getOBXModel("TestEntity");
}

TestEntity _TestEntity_OBXBuilder(Map<String, dynamic> members) {
  TestEntity r = new TestEntity();
  r.id = members["id"];
  r.text = members["text"];
  return r;
}

Map<String, dynamic> _TestEntity_OBXReader(TestEntity inst) {
  Map<String, dynamic> r = {};
  r["id"] = inst.id;
  r["text"] = inst.text;
  return r;
}

const TestEntity_OBXDefs = {
  "model": _TestEntity_OBXModelGetter,
  "builder": _TestEntity_OBXBuilder,
  "reader": _TestEntity_OBXReader,
};
