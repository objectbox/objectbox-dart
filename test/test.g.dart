// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test.dart';

// **************************************************************************
// EntityGenerator
// **************************************************************************

Map<String, Map<String, dynamic>> _allOBXModels = null;

void _loadOBXModels() {
  if (FileSystemEntity.typeSync("test/test.g.json") ==
      FileSystemEntityType.notFound)
    throw Exception("test/test.g.json not found");

  _allOBXModels = {};
  List<dynamic> models =
      json.decode(new File("test/test.g.json").readAsStringSync());
  List<Map<String, dynamic>> modelsTyped =
      models.map<Map<String, dynamic>>((x) => x).toList();
  modelsTyped.forEach((v) => _allOBXModels[v["entity"]["name"]] = v);
}

Map<String, dynamic> _getOBXModel(String entityName) {
  if (_allOBXModels == null) _loadOBXModels();
  if (!_allOBXModels.containsKey(entityName))
    throw Exception("unknown entity name: $entityName");
  return _allOBXModels[entityName];
}

const _TestEntity_OBXModel = {
  "entity": {"name": "TestEntity", "id": 1, "uid": 1},
  "properties": [
    {
      "name": "id",
      "id": 1,
      "uid": 1001,
      "type": 6,
      "flags": 1,
    },
    {
      "name": "text",
      "id": 2,
      "uid": 1002,
      "type": 9,
      "flags": 0,
    },
  ],
  "idPropertyName": "id",
};

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

const _Note_OBXModel = {
  "entity": {"name": "Note", "id": 1, "uid": 1},
  "properties": [
    {
      "name": "id",
      "id": 1,
      "uid": 2001,
      "type": 6,
      "flags": 1,
    },
    {
      "name": "text",
      "id": 2,
      "uid": 2002,
      "type": 9,
      "flags": 0,
    },
  ],
  "idPropertyName": "id",
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
