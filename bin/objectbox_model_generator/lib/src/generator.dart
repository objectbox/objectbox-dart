import "dart:async";
import "dart:convert";
import "dart:io";
import "package:analyzer/dart/element/element.dart";
import "package:build/src/builder/build_step.dart";
import "package:path/path.dart" as path;
import "package:source_gen/source_gen.dart";

import "package:objectbox/objectbox.dart";
import "package:objectbox/src/bindings/constants.dart";

Future<bool> fileExists(name) async {
  return (await FileSystemEntity.type(name)) != FileSystemEntityType.notFound;
}

Future<String> readFile(name) async {
  return await (new File(name).readAsString());
}

class EntityGenerator extends GeneratorForAnnotation<Entity> {
  // each .g.dart file needs to get a header with functions to load the .g.json file exactly once. Store the input .dart file ids this has already been done for here
  List<String> entityHeaderDone = [];

  // returns the JSON model file corresponding to the current Dart source file, i.e. test/test.dart --> test/test.g.json, if it exists
  Future<String> getGeneratedJSONFilename(BuildStep buildStep) async {
    if (!(await buildStep.canRead(buildStep.inputId)))
      throw InvalidGenerationSourceError("cannot read input file id: ${buildStep.inputId}");

    // get the filename of the current target (i.e. the Dart source file containing @Entity annotations, e.g. test/test.dart)
    String inputFilename = buildStep.inputId.path;
    if (buildStep.inputId.extension != ".dart")
      throw InvalidGenerationSourceError("input file name does not have .dart extension: ${inputFilename}");
    if (!(await fileExists(inputFilename)))
      throw InvalidGenerationSourceError("input file does not exist: ${inputFilename}");

    // try getting a previously generated file for this target, no problem if it does not exist
    String genFilename = path.withoutExtension(inputFilename) + ".g.json";
    if (!(await fileExists(genFilename))) return null;
    return genFilename;
  }

  Future<List<Map<String, dynamic>>> _loadJSONModels(String filename) async {
    List<dynamic> allModels = json.decode(await (new File(filename).readAsString()));
    return allModels.map<Map<String, dynamic>>((x) => x).toList();
  }

  Map<String, dynamic> _findJSONModel(List<Map<String, dynamic>> allModels, String entityName) {
    int index = allModels.indexWhere((m) => m["entity"]["name"] == entityName);
    if (index == -1) return null;
    return allModels[index];
  }

  @override
  Future<String> generateForAnnotatedElement(
      Element elementBare, ConstantReader annotation, BuildStep buildStep) async {
    if (elementBare is! ClassElement)
      throw InvalidGenerationSourceError("in target ${elementBare.name}: annotated element isn't a class");
    var element = elementBare as ClassElement;

    // load existing model from JSON file if possible
    String inputFileId = buildStep.inputId.toString();
    String jsonFilename = await getGeneratedJSONFilename(buildStep);
    List<Map<String, dynamic>> allModels = await _loadJSONModels(jsonFilename);
    Map<String, dynamic> currentModel = _findJSONModel(allModels, element.name);

    // optionally add header for loading the .g.json file
    var ret = "";
    if (entityHeaderDone.indexOf(inputFileId) == -1) {
      ret += """
          Map<String, Map<String, dynamic>> _allOBXModels = null;

          void _loadOBXModels() {
            if (FileSystemEntity.typeSync("$jsonFilename") == FileSystemEntityType.notFound)
              throw Exception("$jsonFilename not found");

            _allOBXModels = {};
            List<dynamic> models = json.decode(new File("$jsonFilename").readAsStringSync());
            List<Map<String, dynamic>> modelsTyped = models.map<Map<String, dynamic>>((x) => x).toList();
            modelsTyped.forEach((v) => _allOBXModels[v["entity"]["name"]] = v);
          }

          Map<String, dynamic> _getOBXModel(String entityName) {
            if (_allOBXModels == null) _loadOBXModels();
            if (!_allOBXModels.containsKey(entityName)) throw Exception("unknown entity name: \$entityName");
            return _allOBXModels[entityName];
          }
        """;
      entityHeaderDone.add(inputFileId);
    }

    // process basic entity
    var entity = Entity(id: annotation.read('id').intValue, uid: annotation.read('uid').intValue);
    ret += """
        const _${element.name}_OBXModel = {
          "entity": {
            "name": "${element.name}",
            "id": ${entity.id},
            "uid": ${entity.uid}
          },
          "properties": [
      """;

    // read all suitable annotated properties
    var props = [];
    String idPropertyName;
    for (var f in element.fields) {
      if (f.metadata == null || f.metadata.length != 1) // skip unannotated fields
        continue;
      var annotElmt = f.metadata[0].element as ConstructorElement;
      var annotType = annotElmt.returnType.toString();
      var annotVal = f.metadata[0].computeConstantValue();
      var fieldTypeObj = annotVal.getField("type");
      int fieldType = fieldTypeObj == null ? null : fieldTypeObj.toIntValue();

      var prop = {
        "name": f.name,
        "id": annotVal.getField("id").toIntValue(),
        "uid": annotVal.getField("uid").toIntValue(),
        "flags": 0,
      };

      if (annotType == "Id") {
        if (idPropertyName != null)
          throw InvalidGenerationSourceError(
              "in target ${elementBare.name}: has more than one properties annotated with @Id");
        if (fieldType != null)
          throw InvalidGenerationSourceError(
              "in target ${elementBare.name}: programming error: @Id property may not specify a type");
        if (f.type.toString() != "int")
          throw InvalidGenerationSourceError(
              "in target ${elementBare.name}: field with @Id property has type '${f.type.toString()}', but it must be 'int'");

        fieldType = OBXPropertyType.Long;
        prop["flags"] = OBXPropertyFlag.ID;
        idPropertyName = f.name;
      } else if (annotType == "Property") {
        // nothing special here
      } else {
        // skip unknown annotations
        continue;
      }

      if (fieldType == null) {
        var fieldTypeStr = f.type.toString();
        if (fieldTypeStr == "int")
          fieldType = OBXPropertyType.Int;
        else if (fieldTypeStr == "String")
          fieldType = OBXPropertyType.String;
        else {
          print(
              "warning: skipping field '${f.name}' in entity '${element.name}', as it has the unsupported type '$fieldTypeStr'");
          continue;
        }
      }

      prop["type"] = fieldType;
      props.add(prop);
      ret += """
          {
            "name": "${prop['name']}",
            "id": ${prop['id']},
            "uid": ${prop['uid']},
            "type": ${prop['type']},
            "flags": ${prop['flags']},
          },
        """;
    }

    // some checks on the entity's integrity
    if (idPropertyName == null)
      throw InvalidGenerationSourceError("in target ${elementBare.name}: has no properties annotated with @Id");

    // main code for instance builders and readers
    ret += """
          ],
          "idPropertyName": "${idPropertyName}",
        };

        Map<String, dynamic> _${element.name}_OBXModelGetter() {
          return _getOBXModel("${element.name}");
        }

        ${element.name} _${element.name}_OBXBuilder(Map<String, dynamic> members) {
          ${element.name} r = new ${element.name}();
          ${props.map((p) => "r.${p['name']} = members[\"${p['name']}\"];").join()}
          return r;
        }

        Map<String, dynamic> _${element.name}_OBXReader(${element.name} inst) {
          Map<String, dynamic> r = {};
          ${props.map((p) => "r[\"${p['name']}\"] = inst.${p['name']};").join()}
          return r;
        }

        const ${element.name}_OBXDefs = {
          "model": _${element.name}_OBXModelGetter,
          "builder": _${element.name}_OBXBuilder,
          "reader": _${element.name}_OBXReader,
        };
      """;

    return ret;
  }
}
