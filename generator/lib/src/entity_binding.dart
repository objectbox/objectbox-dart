import "dart:async";
import "dart:convert";
import "dart:io";
import "package:analyzer/dart/element/element.dart";
import 'package:build/build.dart';
import "package:build/src/builder/build_step.dart";
import "package:source_gen/source_gen.dart";
import "package:objectbox/objectbox.dart" as obx;
import "package:objectbox/src/bindings/constants.dart";
import "package:objectbox/src/modelinfo/index.dart";
import "code_chunks.dart";
import "merge.dart";

class EntityGenerator extends GeneratorForAnnotation<obx.Entity> {
  static const modelJSON = "objectbox-model.json";
  static const modelDart = "objectbox_model.dart";

  Future<ModelInfo> _loadModelInfo() async {
    if ((await FileSystemEntity.type(modelJSON)) == FileSystemEntityType.notFound) {
      return ModelInfo.createDefault();
    }
    return ModelInfo.fromMap(json.decode(await (File(modelJSON).readAsString())));
  }

  void _writeModelInfo(ModelInfo modelInfo) async {
    final json = JsonEncoder.withIndent("  ").convert(modelInfo.toMap());
    await File(modelJSON).writeAsString(json);

    final code = CodeChunks.modelInfoDefinition(modelInfo);
    await File(modelDart).writeAsString(code);
  }

  final _propertyChecker = const TypeChecker.fromRuntime(obx.Property);
  final _idChecker = const TypeChecker.fromRuntime(obx.Id);

  @override
  Future<String> generateForAnnotatedElement(
      Element elementBare, ConstantReader annotation, BuildStep buildStep) async {
    try {
      if (elementBare is! ClassElement) {
        throw InvalidGenerationSourceError("in target ${elementBare.name}: annotated element isn't a class");
      }
      var element = elementBare as ClassElement;

      log.warning(buildStep.inputId.toString());

      // load existing model from JSON file if possible
      String inputFileId = buildStep.inputId.toString();
      ModelInfo modelInfo = await _loadModelInfo();

      var code = "";

      // process basic entity (note that allModels.createEntity is not used, as the entity will be merged)
      ModelEntity readEntity = ModelEntity(IdUid.empty(), null, element.name, [], modelInfo);
      var entityUid = annotation.read("uid");
      if (entityUid != null && !entityUid.isNull) readEntity.id.uid = entityUid.intValue;

      // read all suitable annotated properties
      bool hasIdProperty = false;
      for (var f in element.fields) {
        int fieldType, flags = 0;
        int propUid;

        if (_idChecker.hasAnnotationOfExact(f)) {
          if (hasIdProperty) {
            throw InvalidGenerationSourceError(
                "in target ${elementBare.name}: has more than one properties annotated with @Id");
          }
          if (f.type.toString() != "int") {
            throw InvalidGenerationSourceError(
                "in target ${elementBare.name}: field with @Id property has type '${f.type.toString()}', but it must be 'int'");
          }

          hasIdProperty = true;

          fieldType = OBXPropertyType.Long;
          flags |= OBXPropertyFlag.ID;

          final _idAnnotation = _idChecker.firstAnnotationOfExact(f);
          propUid = _idAnnotation.getField('uid').toIntValue();
        } else if (_propertyChecker.hasAnnotationOfExact(f)) {
          final _propertyAnnotation = _propertyChecker.firstAnnotationOfExact(f);
          propUid = _propertyAnnotation.getField('uid').toIntValue();
          fieldType = _propertyAnnotation.getField('type').toIntValue();
          flags = _propertyAnnotation.getField('flag').toIntValue() ?? 0;

          log.info(
              "annotated property found on ${f.name} with parameters: propUid(${propUid}) fieldType(${fieldType}) flags(${flags})");
        } else {
          log.info(
              "property found on ${f.name} with parameters: propUid(${propUid}) fieldType(${fieldType}) flags(${flags})");
        }

        if (fieldType == null) {
          var fieldTypeStr = f.type.toString();

          if (fieldTypeStr == "int") {
            // dart: 8 bytes
            // ob: 8 bytes
            fieldType = OBXPropertyType.Long;
          } else if (fieldTypeStr == "String") {
            fieldType = OBXPropertyType.String;
          } else if (fieldTypeStr == "bool") {
            // dart: 1 byte
            // ob: 1 byte
            fieldType = OBXPropertyType.Bool;
          } else if (fieldTypeStr == "double") {
            // dart: 8 bytes
            // ob: 8 bytes
            fieldType = OBXPropertyType.Double;
          } else {
            log.warning(
                "skipping field '${f.name}' in entity '${element.name}', as it has the unsupported type '$fieldTypeStr'");
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
      mergeEntity(modelInfo, readEntity);
      _writeModelInfo(modelInfo);

      readEntity = modelInfo.findEntityByName(element.name);
      if (readEntity == null) return code;

      // main code for instance builders and readers
      code += CodeChunks.instanceBuildersReaders(readEntity);

      // for building queries
      code += CodeChunks.queryConditionClasses(readEntity);

      return code;
    } catch (e, s) {
      log.warning(s);
      rethrow;
    }
  }
}
