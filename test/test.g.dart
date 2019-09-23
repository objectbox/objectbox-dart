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
  Map<String, dynamic> models =
      json.decode(new File("objectbox-models.json").readAsStringSync());
  models["entities"].forEach((v) => _allOBXModels[v["name"]] = v);
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

Map<String, dynamic> _Note_OBXModelGetter() {
  return _getOBXModel("Note");
}

Note _Note_OBXBuilder(Map<String, dynamic> members) {
  Note r = new Note();
  r.id = members["id"];
  r.text = members["text"];
  return r;
}

Map<String, dynamic> _Note_OBXReader(Note inst) {
  Map<String, dynamic> r = {};
  r["id"] = inst.id;
  r["text"] = inst.text;
  return r;
}

const Note_OBXDefs = {
  "model": _Note_OBXModelGetter,
  "builder": _Note_OBXBuilder,
  "reader": _Note_OBXReader,
};
