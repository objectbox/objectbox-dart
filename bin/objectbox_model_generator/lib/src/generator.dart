import "dart:async";
import "dart:convert";
import "dart:io";
import "package:analyzer/dart/element/element.dart";
import "package:build/src/builder/build_step.dart";
import "package:source_gen/source_gen.dart";

import "package:objectbox/objectbox.dart";
import "package:objectbox/src/bindings/constants.dart";

import "merge.dart";

class EntityGenerator extends GeneratorForAnnotation<Entity> {
  static const ALL_MODELS_JSON = "objectbox_models.json";

  // each .g.dart file needs to get a header with functions to load the ALL_MODELS_JSON file exactly once. Store the input .dart file ids this has already been done for here
  List<String> entityHeaderDone = [];

  Future<List<Map<String, dynamic>>> _loadAllModels() async {
    if ((await FileSystemEntity.type(ALL_MODELS_JSON)) == FileSystemEntityType.notFound) return [];
    List<dynamic> allModels = json.decode(await (new File(ALL_MODELS_JSON).readAsString()));
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
    List<Map<String, dynamic>> allModels = await _loadAllModels();

    // optionally add header for loading the .g.json file
    var ret = "";
    if (entityHeaderDone.indexOf(inputFileId) == -1) {
      ret += """
          Map<String, Map<String, dynamic>> _allOBXModels = null;

          void _loadOBXModels() {
            if (FileSystemEntity.typeSync("$ALL_MODELS_JSON") == FileSystemEntityType.notFound)
              throw Exception("$ALL_MODELS_JSON not found");

            _allOBXModels = {};
            List<dynamic> models = json.decode(new File("$ALL_MODELS_JSON").readAsStringSync());
            List<Map<String, dynamic>> modelsTyped = models.map<Map<String, dynamic>>((x) => x).toList();
            modelsTyped.forEach((v) => _allOBXModels[v["entity"]["name"]] = v);
          }

          Map<String, dynamic> _getOBXModel(String entityName) {
            if (_allOBXModels == null) _loadOBXModels();
            if (!_allOBXModels.containsKey(entityName)) throw Exception("entity missing in $ALL_MODELS_JSON: \$entityName");
            return _allOBXModels[entityName];
          }
        """;
      entityHeaderDone.add(inputFileId);
    }

    // process basic entity
    Map<String, dynamic> annotatedModel = {
      "entity": {
        "name": "${element.name}",
      },
      "properties": [],
    };

    // read all suitable annotated properties
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
        "flags": 0,
      };

      if (annotType == "Id") {
        if (annotatedModel["idPropertyName"] != null)
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
        annotatedModel["idPropertyName"] = f.name;
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
      annotatedModel["properties"].add(prop);
    }

    // some checks on the entity's integrity
    if (annotatedModel["idPropertyName"] == null)
      throw InvalidGenerationSourceError("in target ${elementBare.name}: has no properties annotated with @Id");

    // merge existing model and annotated model that was just read, then write new final model to file
    final List<Map<String, dynamic>> allModelsFinal = merge(allModels, annotatedModel);
    new File(ALL_MODELS_JSON).writeAsString(new JsonEncoder.withIndent("  ").convert(allModelsFinal));
    final Map<String, dynamic> currentModelFinal = _findJSONModel(allModelsFinal, element.name);
    if (currentModelFinal == null) return ret;

    // main code for instance builders and readers
    ret += """
        Map<String, dynamic> _${element.name}_OBXModelGetter() {
          return _getOBXModel("${element.name}");
        }

        ${element.name} _${element.name}_OBXBuilder(Map<String, dynamic> members) {
          ${element.name} r = new ${element.name}();
          ${currentModelFinal["properties"].map((p) => "r.${p['name']} = members[\"${p['name']}\"];").join()}
          return r;
        }

        Map<String, dynamic> _${element.name}_OBXReader(${element.name} inst) {
          Map<String, dynamic> r = {};
          ${currentModelFinal["properties"].map((p) => "r[\"${p['name']}\"] = inst.${p['name']};").join()}
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
