import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:objectbox/objectbox.dart' as obx;
import 'package:objectbox/src/bindings/constants.dart';
import 'package:objectbox/src/modelinfo/index.dart';
import 'package:objectbox/src/util.dart';
import 'package:source_gen/source_gen.dart';

/// EntityResolver finds all classes with an @Entity annotation and generates '.objectbox.info' files in build cache.
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
  final _uniqueChecker = const TypeChecker.fromRuntime(obx.Unique);
  final _indexChecker = const TypeChecker.fromRuntime(obx.Index);

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final resolver = buildStep.resolver;
    if (!await resolver.isLibrary(buildStep.inputId)) return;
    final libReader = LibraryReader(await buildStep.inputLibrary);

    // generate for all entities
    final entities = <Map<String, dynamic>>[];
    for (var annotatedEl in libReader.annotatedWith(_annotationChecker)) {
      entities.add(generateForAnnotatedElement(
              annotatedEl.element, annotatedEl.annotation)
          .toMap());
    }

    if (entities.isEmpty) return;

    final json = JsonEncoder().convert(entities);
    await buildStep.writeAsString(
        buildStep.inputId.changeExtension(suffix), json);
  }

  ModelEntity generateForAnnotatedElement(
      Element elementBare, ConstantReader annotation) {
    if (elementBare is! ClassElement) {
      throw InvalidGenerationSourceError(
          "in target ${elementBare.name}: annotated element isn't a class");
    }
    var element = elementBare as ClassElement;

    // process basic entity (note that allModels.createEntity is not used, as the entity will be merged)
    final readEntity = ModelEntity(IdUid.empty(), null, element.name, [], null);
    var entityUid = annotation.read('uid');
    if (entityUid != null && !entityUid.isNull) {
      readEntity.id.uid = entityUid.intValue;
    }

    log.info('entity ${readEntity.name}(${readEntity.id})');

    // read all suitable annotated properties
    var hasIdProperty = false;
    for (var f in element.fields) {
      if (_transientChecker.hasAnnotationOfExact(f)) {
        log.info('  skipping property ${f.name} (annotated with @Transient)');
        continue;
      }

      int fieldType, flags = 0;
      int propUid, indexUid;

      if (_idChecker.hasAnnotationOfExact(f)) {
        if (hasIdProperty) {
          throw InvalidGenerationSourceError(
              'in target ${elementBare.name}: has more than one properties annotated with @Id');
        }
        if (f.type.toString() != 'int') {
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

        if (fieldTypeStr == 'int') {
          // dart: 8 bytes
          // ob: 8 bytes
          fieldType = OBXPropertyType.Long;
        } else if (fieldTypeStr == 'String') {
          fieldType = OBXPropertyType.String;
        } else if (fieldTypeStr == 'bool') {
          // dart: 1 byte
          // ob: 1 byte
          fieldType = OBXPropertyType.Bool;
        } else if (fieldTypeStr == 'double') {
          // dart: 8 bytes
          // ob: 8 bytes
          fieldType = OBXPropertyType.Double;
        } else {
          log.warning(
              "  skipping property '${f.name}' in entity '${element.name}', as it has the unsupported type '$fieldTypeStr'");
          continue;
        }
      }

      // Index and unique index.
      final indexAnnotation = _indexChecker.firstAnnotationOfExact(f);
      final hasUniqueAnnotation = _uniqueChecker.hasAnnotationOfExact(f);
      if (indexAnnotation != null || hasUniqueAnnotation) {
        // Throw if property type does not support any index.
        if (fieldType == OBXPropertyType.Float || fieldType == OBXPropertyType.Double || fieldType == OBXPropertyType.ByteVector) {
          throw InvalidGenerationSourceError(
              "in target ${elementBare.name}: @Index/@Unique is not supported for type '${f.type.toString()}' of field '${f.name}'");
        }

        // TODO Throw if index used on Id property.


        // If available use index type from annotation.
        var indexFlag;
        if (indexAnnotation != null) {
          indexFlag = indexAnnotation.getField('flag').toIntValue();
          if (indexFlag != null &&
              (indexFlag != OBXPropertyFlag.INDEXED
              || indexFlag != OBXPropertyFlag.INDEX_HASH
              || indexFlag != OBXPropertyFlag.INDEX_HASH64)) {
            throw InvalidGenerationSourceError(
                'in target ${elementBare.name}: @Index flag must be one of [OBXPropertyFlag.INDEXED, OBXPropertyFlag.INDEX_HASH, OBXPropertyFlag.INDEX_HASH64] or none for auto-detection');
          }
        }

        // Fall back to index type based on property type.
        final supportsHashIndex = fieldType == OBXPropertyType.String;
        if (indexFlag == null) {
          if (supportsHashIndex) {
            indexFlag = OBXPropertyFlag.INDEX_HASH;
          } else {
            indexFlag = OBXPropertyFlag.INDEXED;
          }
        }

        // Throw if HASH or HASH64 is not supported by property type.
        if (!supportsHashIndex &&
            (indexFlag == OBXPropertyFlag.INDEX_HASH ||
                indexFlag == OBXPropertyFlag.INDEX_HASH64)) {
          throw InvalidGenerationSourceError(
              "in target ${elementBare.name}: a hash index is not supported for type '${f.type.toString()}' of field '${f.name}'");
        }

        flags |= indexFlag;
        if (hasUniqueAnnotation) {
          flags |= OBXPropertyFlag.UNIQUE;
        }
      }

      // create property (do not use readEntity.createProperty in order to avoid generating new ids)
      final prop =
          ModelProperty(IdUid.empty(), f.name, fieldType, flags, readEntity);

      // TODO test on @Property(...) that uses the proper flags for index
      final isIndexer = flags.isIndexer;

      if (isIndexer) {
        prop.indexId = indexUid == null ? IdUid.empty() : IdUid(0, indexUid);
      }

      if (propUid != null) prop.id.uid = propUid;
      readEntity.properties.add(prop);

      log.info(
          '  ${isIndexer ? "index " : ""}property ${prop.name}(${prop.id}) type:${prop.type} flags:${prop.flags}');
    }

    // some checks on the entity's integrity
    if (!hasIdProperty) {
      throw InvalidGenerationSourceError(
          'in target ${elementBare.name}: has no properties annotated with @Id');
    }

    return readEntity;
  }
}
