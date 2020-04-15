import "dart:async";
import "dart:convert";
import "package:analyzer/dart/element/element.dart";
import 'package:build/build.dart';
import "package:source_gen/source_gen.dart";
import "package:objectbox/objectbox.dart" as obx;
import "package:objectbox/src/bindings/constants.dart";
import "package:objectbox/src/modelinfo/index.dart";

/// EntityResolver finds all classes with an @Entity annotation and generates ".objectbox.info" files in build cache.
/// It's using some tools from source_gen but defining its custom builder because source_gen expects only dart code.
class EntityResolver extends Builder {
  static const suffix = '.objectbox.info';
  @override
  final buildExtensions = {
    '.dart': [suffix]
  };

  final _annotationChecker = const TypeChecker.fromRuntime(obx.Entity);
  final _propertyChecker = const TypeChecker.fromRuntime(obx.Property);
  final _idChecker = const TypeChecker.fromRuntime(obx.Id);
  final _transientChecker = const TypeChecker.fromRuntime(obx.Transient);

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final resolver = buildStep.resolver;
    if (!await resolver.isLibrary(buildStep.inputId)) return;
    final libReader = LibraryReader(await buildStep.inputLibrary);

    // generate for all entities
    final entities = List<Map<String, dynamic>>();
    for (var annotatedEl in libReader.annotatedWith(_annotationChecker)) {
      entities.add(generateForAnnotatedElement(annotatedEl.element, annotatedEl.annotation).toMap());
    }

    if (entities.isEmpty) return;

    final json = JsonEncoder().convert(entities);
    await buildStep.writeAsString(buildStep.inputId.changeExtension(suffix), json);
  }

  ModelEntity generateForAnnotatedElement(Element elementBare, ConstantReader annotation) {
    if (elementBare is! ClassElement) {
      throw InvalidGenerationSourceError("in target ${elementBare.name}: annotated element isn't a class");
    }
    var element = elementBare as ClassElement;

    // process basic entity (note that allModels.createEntity is not used, as the entity will be merged)
    ModelEntity readEntity = ModelEntity(IdUid.empty(), null, element.name, [], null);
    var entityUid = annotation.read("uid");
    if (entityUid != null && !entityUid.isNull) readEntity.id.uid = entityUid.intValue;

    log.info("entity ${readEntity.name}(${readEntity.id})");

    // read all suitable annotated properties
    bool hasIdProperty = false;
    for (var f in element.fields) {

      if (_transientChecker.hasAnnotationOfExact(f)) {
        log.info("  skipping property ${f.name} (annotated with @Transient)");
        continue;
      }

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
              "  skipping property '${f.name}' in entity '${element.name}', as it has the unsupported type '$fieldTypeStr'");
          continue;
        }
      }

      // create property (do not use readEntity.createProperty in order to avoid generating new ids)
      ModelProperty prop = ModelProperty(IdUid.empty(), f.name, fieldType, flags, readEntity);
      if (propUid != null) prop.id.uid = propUid;
      readEntity.properties.add(prop);

      log.info("  property ${prop.name}(${prop.id}) type:${prop.type} flags:${prop.flags}");
    }

    // some checks on the entity's integrity
    if (!hasIdProperty) {
      throw InvalidGenerationSourceError("in target ${elementBare.name}: has no properties annotated with @Id");
    }

    return readEntity;
  }
}
