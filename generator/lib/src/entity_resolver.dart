import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:objectbox/objectbox.dart';
import 'package:objectbox/internal.dart';
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

  final _entityChecker = const TypeChecker.fromRuntime(Entity);
  final _propertyChecker = const TypeChecker.fromRuntime(Property);
  final _idChecker = const TypeChecker.fromRuntime(Id);
  final _transientChecker = const TypeChecker.fromRuntime(Transient);
  final _syncChecker = const TypeChecker.fromRuntime(Sync);
  final _uniqueChecker = const TypeChecker.fromRuntime(Unique);
  final _indexChecker = const TypeChecker.fromRuntime(Index);
  final _backlinkChecker = const TypeChecker.fromRuntime(Backlink);

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final resolver = buildStep.resolver;
    if (!await resolver.isLibrary(buildStep.inputId)) return;
    final libReader = LibraryReader(await buildStep.inputLibrary);

    // generate for all entities
    final entities = <Map<String, dynamic>>[];
    for (var annotatedEl in libReader.annotatedWith(_entityChecker)) {
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
          "entity ${elementBare.name}: annotated element isn't a class");
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
    final readOnlyFields = <String>{};
    for (var f in element.accessors) {
      if (f.isGetter && f.correspondingSetter == null) {
        readOnlyFields.add(f.name);
      }
    }

    // read all suitable annotated properties
    for (var f in element.fields) {
      if (_transientChecker.hasAnnotationOfExact(f)) {
        log.info('  skipping property ${f.name} (annotated with @Transient)');
        continue;
      }

      if (readOnlyFields.contains(f.name) && !isRelationField(f)) {
        log.info('  skipping read-only/getter ${f.name}');
        continue;
      }

      var isToManyRel = false;
      int fieldType;
      var flags = 0;
      int propUid;
      String dartFieldType; // to be passed to ModelProperty.dartFieldType

      if (_idChecker.hasAnnotationOfExact(f)) {
        flags |= OBXPropertyFlags.ID;
      }

      if (_propertyChecker.hasAnnotationOfExact(f)) {
        final _propertyAnnotation = _propertyChecker.firstAnnotationOfExact(f);
        propUid = _propertyAnnotation.getField('uid').toIntValue();
        fieldType =
            propertyTypeFromAnnotation(_propertyAnnotation.getField('type'));
      }

      if (fieldType == null) {
        final fieldTypeDart = f.type;

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
        } else if (['Int8List', 'Uint8List']
            .contains(fieldTypeDart.element.name)) {
          fieldType = OBXPropertyType.ByteVector;
          dartFieldType = fieldTypeDart.element.name; // for code generation
        } else if (isToOneRelationField(f)) {
          fieldType = OBXPropertyType.Relation;
        } else if (isToManyRelationField(f)) {
          isToManyRel = true;
        } else {
          log.warning(
              "  skipping property '${f.name}' in entity '${element.name}', as it has an unsupported type: '${fieldTypeDart}'");
          continue;
        }
      }

      String relTargetName;
      if (isRelationField(f)) {
        if (f.type is! ParameterizedType) {
          log.severe(
              "  invalid relation property '${f.name}' in entity '${element.name}' - must use ToOne/ToMany<TargetEntity>");
          continue;
        }
        relTargetName =
            (f.type as ParameterizedType).typeArguments[0].element.name;
      }

      if (_backlinkChecker.hasAnnotationOfExact(f)) {
        if (!isToManyRel) {
          log.severe(
              '  invalid use of @Backlink() annotation - may only be used on a ToMany<> field');
          continue;
        }
        final backlinkField = _backlinkChecker
            .firstAnnotationOfExact(f)
            .getField('to')
            .toStringValue();
        final backlink = ModelBacklink(f.name, relTargetName, backlinkField);
        entity.backlinks.add(backlink);
        log.info('  ${backlink}');
      } else if (isToManyRel) {
        // create relation
        final rel =
            ModelRelation(IdUid.empty(), f.name, targetName: relTargetName);
        if (propUid != null) rel.id.uid = propUid;
        entity.relations.add(rel);

        log.info('  ${rel}');
      } else {
        // create property (do not use readEntity.createProperty in order to avoid generating new ids)
        final prop = ModelProperty(IdUid.empty(), f.name, fieldType,
            flags: flags, entity: entity);

        if (fieldType == OBXPropertyType.Relation) {
          prop.name += 'Id';
          prop.relationTarget = relTargetName;
          prop.flags |= OBXPropertyFlags.INDEXED;
          prop.flags |= OBXPropertyFlags.INDEX_PARTIAL_SKIP_ZERO;
        }

        // Index and unique annotation.
        processAnnotationIndexUnique(f, fieldType, elementBare, prop);

        if (propUid != null) prop.id.uid = propUid;
        prop.dartFieldType = dartFieldType;
        entity.properties.add(prop);
      }
    }

    processIdProperty(entity);

    entity.properties.forEach((p) => log.info('  ${p}'));

    return entity;
  }

  void processIdProperty(ModelEntity entity) {
    // check properties explicitly annotated with @Id()
    final annotated =
        entity.properties.where((p) => p.hasFlag(OBXPropertyFlags.ID));
    if (annotated.length > 1) {
      throw InvalidGenerationSourceError(
          'entity ${entity.name}: multiple fields annotated with Id(), there may only be one');
    }

    if (annotated.length == 1) {
      if (annotated.first.type != OBXPropertyType.Long) {
        throw InvalidGenerationSourceError(
            "entity ${entity.name}: Id() annotated property has invalid type, expected 'int'");
      }
    } else {
      // if there are no annotated props, try to find one by name & type
      final candidates = entity.properties.where((p) =>
          p.name.toLowerCase() == 'id' && p.type == OBXPropertyType.Long);
      if (candidates.length != 1) {
        throw InvalidGenerationSourceError(
            'entity ${entity.name}: ID property not found - either define '
            ' an integer field named ID/id/... (case insensitive) or add '
            ' @Id annotation to any integer field');
      }
      candidates.first.flags |= OBXPropertyFlags.ID;
    }

    // finally, ensure ID field compatibility with other bindings
    final idProperty =
        entity.properties.singleWhere((p) => p.hasFlag(OBXPropertyFlags.ID));

    // IDs must not be tagged unsigned for compatibility reasons
    idProperty.flags &= ~OBXPropertyFlags.UNSIGNED;
  }

  void processAnnotationIndexUnique(
      FieldElement f, int fieldType, Element elementBare, ModelProperty prop) {
    IndexType indexType;

    final indexAnnotation = _indexChecker.firstAnnotationOfExact(f);
    final hasUniqueAnnotation = _uniqueChecker.hasAnnotationOfExact(f);
    if (indexAnnotation == null && !hasUniqueAnnotation) return null;

    // Throw if property type does not support any index.
    if (fieldType == OBXPropertyType.Float ||
        fieldType == OBXPropertyType.Double ||
        fieldType == OBXPropertyType.ByteVector) {
      throw InvalidGenerationSourceError(
          "entity ${elementBare.name}: @Index/@Unique is not supported for type '${f.type}' of field '${f.name}'");
    }

    if (prop.hasFlag(OBXPropertyFlags.ID)) {
      throw InvalidGenerationSourceError(
          'entity ${elementBare.name}: @Index/@Unique is not supported for ID field ${f.name}. IDs are unique by definition and automatically indexed');
    }

    // If available use index type from annotation.
    if (indexAnnotation != null && !indexAnnotation.isNull) {
      final enumValItem = enumValueItem(indexAnnotation.getField('type'));
      if (enumValItem != null) indexType = IndexType.values[enumValItem];
    }

    // Fall back to index type based on property type.
    final supportsHashIndex = fieldType == OBXPropertyType.String;
    if (indexType == null) {
      if (supportsHashIndex) {
        indexType = IndexType.hash;
      } else {
        indexType = IndexType.value;
      }
    }

    // Throw if HASH or HASH64 is not supported by property type.
    if (!supportsHashIndex &&
        (indexType == IndexType.hash || indexType == IndexType.hash64)) {
      throw InvalidGenerationSourceError(
          "entity ${elementBare.name}: a hash index is not supported for type '${f.type}' of field '${f.name}'");
    }

    if (hasUniqueAnnotation) {
      prop.flags |= OBXPropertyFlags.UNIQUE;
    }

    switch (indexType) {
      case IndexType.value:
        prop.flags |= OBXPropertyFlags.INDEXED;
        break;
      case IndexType.hash:
        prop.flags |= OBXPropertyFlags.INDEX_HASH;
        break;
      case IndexType.hash64:
        prop.flags |= OBXPropertyFlags.INDEX_HASH64;
        break;
      default:
        throw InvalidGenerationSourceError(
            'entity ${elementBare.name}: invalid index type: $indexType');
    }
  }

  int /*?*/ enumValueItem(DartObject typeField) {
    if (!typeField.isNull) {
      final enumValues = (typeField.type as InterfaceType)
          .element
          .fields
          .where((f) => f.isEnumConstant)
          .toList();

      // Find the index of the matching enum constant.
      for (var i = 0; i < enumValues.length; i++) {
        if (enumValues[i].computeConstantValue() == typeField) {
          return i;
        }
      }
    }

    return null;
  }

  // find out @Property(type:) field value - its an enum PropertyType
  int /*?*/ propertyTypeFromAnnotation(DartObject typeField) {
    final item = enumValueItem(typeField);
    return item == null
        ? null
        : propertyTypeToOBXPropertyType(PropertyType.values[item]);
  }

  DartType /*?*/ listItemType(DartType listType) {
    final typeArgs =
        listType is ParameterizedType ? listType.typeArguments : [];
    return typeArgs.length == 1 ? typeArgs[0] : null;
  }

  bool isRelationField(FieldElement f) =>
      isToOneRelationField(f) || isToManyRelationField(f);

  bool isToOneRelationField(FieldElement f) => f.type.element.name == 'ToOne';

  bool isToManyRelationField(FieldElement f) => f.type.element.name == 'ToMany';
}
