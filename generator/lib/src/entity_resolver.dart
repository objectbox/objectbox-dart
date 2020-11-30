import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:objectbox/objectbox.dart' as obx;
import 'package:objectbox/src/bindings/bindings.dart';
import 'package:objectbox/src/bindings/helpers.dart';
import 'package:objectbox/src/modelinfo/index.dart';
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
  final _syncChecker = const TypeChecker.fromRuntime(obx.Sync);
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
    final entity = ModelEntity(IdUid.empty(), element.name, null);
    var entityUid = annotation.read('uid');
    if (entityUid != null && !entityUid.isNull) {
      entity.id.uid = entityUid.intValue;
    }

    if (_syncChecker.hasAnnotationOfExact(element)) {
      entity.flags |= OBXEntityFlags.SYNC_ENABLED;
    }

    log.info(entity);

    // getters, ... (anything else?)
    final readOnlyFields = <String, bool>{};
    for (var f in element.accessors) {
      if (f.isGetter && f.correspondingSetter == null) {
        readOnlyFields[f.name] = true;
      }
    }

    // read all suitable annotated properties
    var hasIdProperty = false;
    for (var f in element.fields) {
      if (_transientChecker.hasAnnotationOfExact(f)) {
        log.info('  skipping property ${f.name} (annotated with @Transient)');
        continue;
      }

      if (readOnlyFields.containsKey(f.name)) {
        log.info('  skipping read-only/getter ${f.name}');
        continue;
      }

      int fieldType;
      var flags = 0;
      int propUid;
      String dartFieldType; // to be passed to ModelProperty.dartFieldType

      if (_idChecker.hasAnnotationOfExact(f)) {
        if (hasIdProperty) {
          throw InvalidGenerationSourceError(
              'in target ${elementBare.name}: has more than one properties annotated with @Id');
        }
        if (!f.type.isDartCoreInt) {
          throw InvalidGenerationSourceError(
              "in target ${elementBare.name}: field with @Id property has type '${f.type}', but it must be 'int'");
        }

        hasIdProperty = true;

        fieldType = OBXPropertyType.Long;
        flags |= OBXPropertyFlags.ID;

        final _idAnnotation = _idChecker.firstAnnotationOfExact(f);
        propUid = _idAnnotation.getField('uid').toIntValue();
      } else if (_propertyChecker.hasAnnotationOfExact(f)) {
        final _propertyAnnotation = _propertyChecker.firstAnnotationOfExact(f);
        propUid = _propertyAnnotation.getField('uid').toIntValue();
        fieldType =
            propertyTypeFromAnnotation(_propertyAnnotation.getField('type'));
        flags = _propertyAnnotation.getField('flag').toIntValue() ?? 0;
      }

      if (fieldType == null) {
        var fieldTypeDart = f.type;

        if (fieldTypeDart.isDartCoreInt) {
          // dart: 8 bytes
          // ob: 8 bytes
          fieldType = OBXPropertyType.Long;
        } else if (fieldTypeDart.isDartCoreString) {
          fieldType = OBXPropertyType.String;
        } else if (fieldTypeDart.isDartCoreBool) {
          // dart: 1 byte
          // ob: 1 byte
          fieldType = OBXPropertyType.Bool;
        } else if (fieldTypeDart.isDartCoreDouble) {
          // dart: 8 bytes
          // ob: 8 bytes
          fieldType = OBXPropertyType.Double;
        } else if (fieldTypeDart.isDartCoreList &&
            listItemType(fieldTypeDart).isDartCoreString) {
          // List<String>
          fieldType = OBXPropertyType.StringVector;
        } else if (fieldTypeDart.element.name == 'Int8List') {
          fieldType = OBXPropertyType.ByteVector;
          dartFieldType =
              fieldTypeDart.element.name; // needed for code generation
        } else if (fieldTypeDart.element.name == 'Uint8List') {
          fieldType = OBXPropertyType.ByteVector;
          // TODO check if UNSIGNED also applies to byte-vector in the core
          flags |= OBXPropertyFlags.UNSIGNED;
          dartFieldType =
              fieldTypeDart.element.name; // needed for code generation
        } else {
          log.warning(
              "  skipping property '${f.name}' in entity '${element.name}', as it has an unsupported type: '${fieldTypeDart}'");
          continue;
        }
      }

      // create property (do not use readEntity.createProperty in order to avoid generating new ids)
      final prop = ModelProperty(IdUid.empty(), f.name, fieldType,
          flags: flags, entity: entity);

      // Index and unique annotation.
      processAnnotationIndexUnique(f, fieldType, elementBare, prop);

      if (propUid != null) prop.id.uid = propUid;
      prop.dartFieldType = dartFieldType;
      entity.properties.add(prop);

      log.info('  ${prop}');
    }

    // some checks on the entity's integrity
    if (!hasIdProperty) {
      throw InvalidGenerationSourceError(
          'in target ${elementBare.name}: has no properties annotated with @Id');
    }

    return entity;
  }

  void processAnnotationIndexUnique(FieldElement f, int fieldType,
      Element elementBare, obx.ModelProperty prop) {
    obx.IndexType indexType;

    final indexAnnotation = _indexChecker.firstAnnotationOfExact(f);
    final hasUniqueAnnotation = _uniqueChecker.hasAnnotationOfExact(f);
    if (indexAnnotation == null && !hasUniqueAnnotation) return null;

    // Throw if property type does not support any index.
    if (fieldType == OBXPropertyType.Float ||
        fieldType == OBXPropertyType.Double ||
        fieldType == OBXPropertyType.ByteVector) {
      throw InvalidGenerationSourceError(
          "in target ${elementBare.name}: @Index/@Unique is not supported for type '${f.type}' of field '${f.name}'");
    }

    if (prop.hasFlag(OBXPropertyFlags.ID)) {
      throw InvalidGenerationSourceError(
          'in target ${elementBare.name}: @Index/@Unique is not supported for ID field ${f.name}. IDs are unique by definition and automatically indexed');
    }

    // If available use index type from annotation.
    if (indexAnnotation != null && !indexAnnotation.isNull) {
      // find out @Index(type:) value - its an enum IndexType
      final indexTypeField = indexAnnotation.getField('type');
      if (!indexTypeField.isNull) {
        final indexTypeEnumValues = (indexTypeField.type as InterfaceType)
            .element
            .fields
            .where((f) => f.isEnumConstant)
            .toList();

        // Find the index of the matching enum constant.
        for (var i = 0; i < indexTypeEnumValues.length; i++) {
          if (indexTypeEnumValues[i].computeConstantValue() == indexTypeField) {
            indexType = obx.IndexType.values[i];
            break;
          }
        }
      }
    }

    // Fall back to index type based on property type.
    final supportsHashIndex = fieldType == OBXPropertyType.String;
    if (indexType == null) {
      if (supportsHashIndex) {
        indexType = obx.IndexType.hash;
      } else {
        indexType = obx.IndexType.value;
      }
    }

    // Throw if HASH or HASH64 is not supported by property type.
    if (!supportsHashIndex &&
        (indexType == obx.IndexType.hash ||
            indexType == obx.IndexType.hash64)) {
      throw InvalidGenerationSourceError(
          "in target ${elementBare.name}: a hash index is not supported for type '${f.type}' of field '${f.name}'");
    }

    if (hasUniqueAnnotation) {
      prop.flags |= OBXPropertyFlags.UNIQUE;
    }

    switch (indexType) {
      case obx.IndexType.value:
        prop.flags |= OBXPropertyFlags.INDEXED;
        break;
      case obx.IndexType.hash:
        prop.flags |= OBXPropertyFlags.INDEX_HASH;
        break;
      case obx.IndexType.hash64:
        prop.flags |= OBXPropertyFlags.INDEX_HASH64;
        break;
      default:
        throw InvalidGenerationSourceError(
            'in target ${elementBare.name}: invalid index type: $indexType');
    }
  }

  // find out @Property(type:) field value - its an enum PropertyType
  int /*?*/ propertyTypeFromAnnotation(DartObject typeField) {
    if (typeField.isNull) return null;
    final enumValues = (typeField.type as InterfaceType)
        .element
        .fields
        .where((f) => f.isEnumConstant)
        .toList();

    // Find the index of the matching enum constant.
    for (var i = 0; i < enumValues.length; i++) {
      if (enumValues[i].computeConstantValue() == typeField) {
        return propertyTypeToOBXPropertyType(obx.PropertyType.values[i]);
      }
    }

    return null;
  }

  DartType /*?*/ listItemType(DartType listType) {
    final typeArgs =
        listType is ParameterizedType ? listType.typeArguments : [];
    return typeArgs.length == 1 ? typeArgs[0] : null;
  }
}
