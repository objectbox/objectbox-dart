// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// EntityGenerator
// **************************************************************************

const _Note_OBXModel = {
  "entity": {"name": "Note", "id": 1, "uid": 1},
  "properties": [
    {
      "name": "id",
      "id": 1,
      "uid": 1001,
      "type": 6,
      "flags": 1,
      "flatbuffers_id": 0,
    },
    {
      "name": "text",
      "id": 2,
      "uid": 1002,
      "type": 9,
      "flags": 0,
      "flatbuffers_id": 1,
    },
  ],
  "idPropertyName": "id",
};

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
  "model": _Note_OBXModel,
  "builder": _Note_OBXBuilder,
  "reader": _Note_OBXReader,
};
