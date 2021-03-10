import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:objectbox/objectbox.dart';
import 'package:objectbox/internal.dart';
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
      Element element, ConstantReader annotation) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
          "entity ${element.name}: annotated element isn't a class");
    }

    // process basic entity (note that allModels.createEntity is not used, as the entity will be merged)
    final entity = ModelEntity(IdUid.empty(), element.name, null);
    var entityUid = annotation.read('uid');
    if (!entityUid.isNull) {
      entity.id.uid = entityUid.intValue;
    }

    if (_syncChecker.hasAnnotationOfExact(element)) {
      entity.flags |= OBXEntityFlags.SYNC_ENABLED;
    }

    log.info(entity);

    entity.constructorParams = constructorParams(findConstructor(element));
    entity.nullSafetyEnabled = nullSafetyEnabled(element);
    if (!entity.nullSafetyEnabled) {
      log.warning(
          "Entity ${entity.name} is in a library/application that doesn't use null-safety"
          ' - consider increasing your SDK version to Flutter 2.0/Dart 2.12');
    }

    // getters, ... (anything else?)
    // TODO are these also final fields? we can now store those if they're among constructor params
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
      int? fieldType;
      var flags = 0;
      int? propUid;

      if (_idChecker.hasAnnotationOfExact(f)) {
        flags |= OBXPropertyFlags.ID;

        final annotation = _idChecker.firstAnnotationOfExact(f);
        if (annotation.getField('assignable')!.toBoolValue()!) {
          flags |= OBXPropertyFlags.ID_SELF_ASSIGNABLE;
        }
      }

      if (_propertyChecker.hasAnnotationOfExact(f)) {
        final annotation = _propertyChecker.firstAnnotationOfExact(f);
        propUid = annotation.getField('uid')!.toIntValue();
        fieldType = propertyTypeFromAnnotation(annotation.getField('type')!);
      }

      if (fieldType == null) {
        final dartType = f.type;

        if (dartType.isDartCoreInt) {
          // dart: 8 bytes
          // ob: 8 bytes
          fieldType = OBXPropertyType.Long;
        } else if (dartType.isDartCoreString) {
          fieldType = OBXPropertyType.String;
        } else if (dartType.isDartCoreBool) {
          // dart: 1 byte
          // ob: 1 byte
          fieldType = OBXPropertyType.Bool;
        } else if (dartType.isDartCoreDouble) {
          // dart: 8 bytes
          // ob: 8 bytes
          fieldType = OBXPropertyType.Double;
        } else if (dartType.isDartCoreList &&
            listItemType(dartType)!.isDartCoreString) {
          // List<String>
          fieldType = OBXPropertyType.StringVector;
        } else if (['Int8List', 'Uint8List'].contains(dartType.element!.name)) {
          fieldType = OBXPropertyType.ByteVector;
        } else if (dartType.element!.name == 'DateTime') {
          fieldType = OBXPropertyType.Date;
          log.warning(
              "  DateTime property '${f.name}' in entity '${element.name}' is stored and read using millisecond precision. "
              'To silence this warning, add an explicit type using @Property(type: PropertyType.date) or @Property(type: PropertyType.dateNano) annotation.');
        } else if (isToOneRelationField(f)) {
          fieldType = OBXPropertyType.Relation;
        } else if (isToManyRelationField(f)) {
          isToManyRel = true;
        } else {
          log.warning(
              "  skipping property '${f.name}' in entity '${element.name}', as it has an unsupported type: '$dartType'");
          continue;
        }
      }

      String? relTargetName;
      if (isRelationField(f)) {
        if (f.type is! ParameterizedType) {
          log.severe(
              "  invalid relation property '${f.name}' in entity '${element.name}' - must use ToOne/ToMany<TargetEntity>");
          continue;
        }
        relTargetName =
            (f.type as ParameterizedType).typeArguments[0].element!.name;
      }

      if (_backlinkChecker.hasAnnotationOfExact(f)) {
        if (!isToManyRel) {
          log.severe(
              '  invalid use of @Backlink() annotation - may only be used on a ToMany<> field');
          continue;
        }
        final backlinkField = _backlinkChecker
            .firstAnnotationOfExact(f)
            .getField('to')!
            .toStringValue()!;
        final backlink = ModelBacklink(f.name, relTargetName!, backlinkField);
        entity.backlinks.add(backlink);
        log.info('  $backlink');
      } else if (isToManyRel) {
        // create relation
        final rel =
            ModelRelation(IdUid.empty(), f.name, targetName: relTargetName);
        if (propUid != null) rel.id.uid = propUid;
        entity.relations.add(rel);

        log.info('  $rel');
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
        processAnnotationIndexUnique(f, fieldType, element, prop);

        if (propUid != null) prop.id.uid = propUid;
        // for code generation
        prop.dartFieldType =
            f.type.element!.name! + (isNullable(f.type) ? '?' : '');
        entity.properties.add(prop);
      }
    }

    processIdProperty(entity);

    entity.properties.forEach((p) => log.info('  $p'));

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
      FieldElement f, int? fieldType, Element elementBare, ModelProperty prop) {
    IndexType? indexType;

    final hasIndexAnnotation = _indexChecker.hasAnnotationOfExact(f);
    final hasUniqueAnnotation = _uniqueChecker.hasAnnotationOfExact(f);
    if (!hasIndexAnnotation && !hasUniqueAnnotation) return null;

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
    final indexAnnotation =
        hasIndexAnnotation ? _indexChecker.firstAnnotationOfExact(f) : null;
    if (indexAnnotation != null && !indexAnnotation.isNull) {
      final enumValItem = enumValueItem(indexAnnotation.getField('type')!);
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

  int? enumValueItem(DartObject typeField) {
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
  int? propertyTypeFromAnnotation(DartObject typeField) {
    final item = enumValueItem(typeField);
    return item == null
        ? null
        : propertyTypeToOBXPropertyType(PropertyType.values[item]);
  }

  DartType? listItemType(DartType listType) {
    final typeArgs =
        listType is ParameterizedType ? listType.typeArguments : [];
    return typeArgs.length == 1 ? typeArgs[0] : null;
  }

  bool isRelationField(FieldElement f) =>
      isToOneRelationField(f) || isToManyRelationField(f);

  bool isToOneRelationField(FieldElement f) => f.type.element!.name == 'ToOne';

  bool isToManyRelationField(FieldElement f) =>
      f.type.element!.name == 'ToMany';

  bool isNullable(DartType type) =>
      type.nullabilitySuffix == NullabilitySuffix.star ||
      type.nullabilitySuffix == NullabilitySuffix.question;

  // Find an unnamed constructor we can use to initialize
  ConstructorElement? findConstructor(ClassElement entity) {
    final index = entity.constructors.indexWhere((c) => c.name.isEmpty);
    return index >= 0 ? entity.constructors[index] : null;
  }

  List<String> constructorParams(ConstructorElement? constructor) {
    if (constructor == null) return List.empty();
    return constructor.parameters.map((param) {
      var info = param.name;
      if (param.isRequiredPositional) info += ' positional';
      if (param.isOptionalPositional) info += ' optional';
      if (param.isNamed) info += ' named';
      return info;
    }).toList(growable: false);
  }

  // To support apps that don't yet use null-safety (depend on an older SDK),
  // we generate code without null-safety operators.
  bool nullSafetyEnabled(Element element) {
    final sdk = element.library!.languageVersion.effective;
    return sdk.major > 2 || (sdk.major == 2 && sdk.minor >= 12);
  }
}
