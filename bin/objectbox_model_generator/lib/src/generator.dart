import "dart:async";
import "dart:convert";
import "dart:io";
import "package:analyzer/dart/element/element.dart";
import "package:build/src/builder/build_step.dart";
import "package:source_gen/source_gen.dart";

import "package:objectbox/objectbox.dart" as obx;
import "package:objectbox/src/bindings/constants.dart";

import "code_chunks.dart";
import "merge.dart";
import "package:objectbox/src/modelinfo/index.dart";

class EntityGenerator extends GeneratorForAnnotation<obx.Entity> {
  static const ALL_MODELS_JSON = "objectbox-model.json";

  // each .g.dart file needs to get a header with functions to load the ALL_MODELS_JSON file exactly once. Store the input .dart file ids this has already been done for here
  List<String> entityHeaderDone = [];

  Future<ModelInfo> _loadModelInfo() async {
    if ((await FileSystemEntity.type(ALL_MODELS_JSON)) == FileSystemEntityType.notFound) {
      return ModelInfo.createDefault();
    }
    return ModelInfo.fromMap(json.decode(await (File(ALL_MODELS_JSON).readAsString())));
  }

  @override
  Future<String> generateForAnnotatedElement(
      Element elementBare, ConstantReader annotation, BuildStep buildStep) async {
    try {
      if (elementBare is! ClassElement) {
        throw InvalidGenerationSourceError("in target ${elementBare.name}: annotated element isn't a class");
      }
      var element = elementBare as ClassElement;

      // load existing model from JSON file if possible
      String inputFileId = buildStep.inputId.toString();
      ModelInfo allModels = await _loadModelInfo();

      // optionally add header for loading the .g.json file
      var ret = "";
      if (entityHeaderDone.indexOf(inputFileId) == -1) {
        ret += CodeChunks.modelInfoLoader();
        entityHeaderDone.add(inputFileId);
      }

      // process basic entity (note that allModels.createEntity is not used, as the entity will be merged)
      ModelEntity readEntity = ModelEntity(IdUid.empty(), null, element.name, [], allModels);
      var entityUid = annotation.read("uid");
      if (entityUid != null && !entityUid.isNull) readEntity.id.uid = entityUid.intValue;

      // read all suitable annotated properties
      bool hasIdProperty = false;
      for (var f in element.fields) {
        int fieldType, flags = 0;
        int propUid;

        if (f.metadata != null && f.metadata.length == 1) {
          var annotElmt = f.metadata[0].element as ConstructorElement;
          var annotType = annotElmt.returnType.toString();
          var annotVal = f.metadata[0].computeConstantValue();
          var fieldTypeAnnot; // for the future, with custom type sizes allowed: annotVal.getField("type");
          fieldType = fieldTypeAnnot?.toIntValue();
          propUid = annotVal.getField("uid").toIntValue();

          // find property flags
          if (annotType == "Id") {
            if (hasIdProperty) {
              throw InvalidGenerationSourceError(
                  "in target ${elementBare.name}: has more than one properties annotated with @Id");
            }
            if (fieldType != null) {
              throw InvalidGenerationSourceError(
                  "in target ${elementBare.name}: programming error: @Id property may not specify a type");
            }
            if (f.type.toString() != "int") {
              throw InvalidGenerationSourceError(
                  "in target ${elementBare.name}: field with @Id property has type '${f.type.toString()}', but it must be 'int'");
            }

            fieldType = OBXPropertyType.Long;
            flags |= OBXPropertyFlag.ID;
            hasIdProperty = true;
          } else if (annotType == "Property") {
            // nothing special
          } else {
            // skip unknown annotations
            print(
                "warning: skipping field '${f.name}' in entity '${element.name}', as it has the unknown annotation type '$annotType'");
            continue;
          }
        }

        if (fieldType == null) {
          var fieldTypeStr = f.type.toString();
          if (fieldTypeStr == "int") {
            fieldType = OBXPropertyType.Int;
          } else if (fieldTypeStr == "String") {
            fieldType = OBXPropertyType.String;
          } else {
            print(
                "warning: skipping field '${f.name}' in entity '${element.name}', as it has the unsupported type '$fieldTypeStr'");
            continue;
          }
        }

        // create property (do not use readEntity.createProperty in order to avoid generating new ids)
        ModelProperty prop = ModelProperty(IdUid.empty(), f.name, fieldType, flags, readEntity);
        if (propUid != null) prop.id.uid = propUid;
        readEntity.properties.add(prop);
      }

      // some checks on the entity's integrity
      if (!hasIdProperty) {
        throw InvalidGenerationSourceError("in target ${elementBare.name}: has no properties annotated with @Id");
      }

      // merge existing model and annotated model that was just read, then write new final model to file
      mergeEntity(allModels, readEntity);
      File(ALL_MODELS_JSON).writeAsString(JsonEncoder.withIndent("  ").convert(allModels.toMap()));
      readEntity = allModels.findEntityByName(element.name);
      if (readEntity == null) return ret;

      // main code for instance builders and readers
      ret += CodeChunks.instanceBuildersReaders(readEntity);

      return ret;
    } catch (e, s) {
      print(s);
      rethrow;
    }
  }
}
