import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:objectbox/internal.dart';
import 'package:objectbox/objectbox.dart';
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
    final entityUid = annotation.read('uid');
    final entityRealClass = annotation.read('realClass');
    final entity = ModelEntity.create(
        IdUid(0, entityUid.isNull ? 0 : entityUid.intValue),
        entityRealClass.isNull
            ? element.name
            : entityRealClass.typeValue.element!.name!,
        null,
        uidRequest: !entityUid.isNull && entityUid.intValue == 0);

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

    // Make sure all stored fields are writable when reading object from DB.
    // Let's filter read-only fields, i.e those that:
    //   * don't have a setter, and
    //   * don't have a corresponding argument in the constructor.
    // Note: `.correspondingSetter == null` is also true for `final` fields.
    final readOnlyFields = <String>{};
    for (var f in element.accessors) {
      if (f.isGetter &&
          f.correspondingSetter == null &&
          !entity.constructorParams
              .any((String param) => param.startsWith('${f.name} '))) {
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

      if (f.isPrivate) {
        log.info('  skipping private field ${f.name}');
        continue;
      }

      var isToManyRel = false;
      int? fieldType;
      var flags = 0;
      int? propUid;

      _idChecker.runIfMatches(f, (annotation) {
        flags |= OBXPropertyFlags.ID;
        if (annotation.getField('assignable')!.toBoolValue()!) {
          flags |= OBXPropertyFlags.ID_SELF_ASSIGNABLE;
        }
      });

      _propertyChecker.runIfMatches(f, (annotation) {
        propUid = annotation.getField('uid')!.toIntValue();
        fieldType = propertyTypeFromAnnotation(annotation.getField('type')!);
        if (!annotation.getField('signed')!.toBoolValue()!) {
          flags |= OBXPropertyFlags.UNSIGNED;
        }
      });

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

      final backlinkAnnotations = _backlinkChecker.annotationsOfExact(f);
      if (backlinkAnnotations.isNotEmpty) {
        if (!isToManyRel) {
          log.severe(
              '  invalid use of @Backlink() annotation - may only be used on a ToMany<> field');
          continue;
        }
        final backlinkField =
            backlinkAnnotations.first.getField('to')!.toStringValue()!;
        final backlink = ModelBacklink(
            name: f.name, srcEntity: relTargetName!, srcField: backlinkField);
        entity.backlinks.add(backlink);
        log.info('  $backlink');
      } else if (isToManyRel) {
        // create relation
        final rel = ModelRelation.create(IdUid(0, propUid ?? 0), f.name,
            targetName: relTargetName,
            uidRequest: propUid != null && propUid == 0);
        entity.relations.add(rel);

        log.info('  $rel');
      } else {
        // create property (do not use readEntity.createProperty in order to avoid generating new ids)
        final prop = ModelProperty.create(
            IdUid(0, propUid ?? 0), f.name, fieldType,
            flags: flags,
            entity: entity,
            uidRequest: propUid != null && propUid == 0);

        if (fieldType == OBXPropertyType.Relation) {
          prop.name += 'Id';
          prop.relationTarget = relTargetName;
          prop.flags |= OBXPropertyFlags.INDEXED;
          prop.flags |= OBXPropertyFlags.INDEX_PARTIAL_SKIP_ZERO;

          // IDs must not be tagged unsigned for compatibility reasons
          prop.flags &= ~OBXPropertyFlags.UNSIGNED;
        }

        // Index and unique annotation.
        processAnnotationIndexUnique(f, fieldType, element, prop);

        // for code generation
        prop.dartFieldType =
            f.type.element!.name! + (isNullable(f.type) ? '?' : '');
        entity.properties.add(prop);
      }
    }

    processIdProperty(entity);

    // We need to check that the ID field is writable. Otherwise, generated code
    // for `setId()` won't compile. The only exception is when user uses
    // self-assigned IDs, then a different setter will be generated - one that
    // checks the ID being set is already the same, otherwise it must throw.
    final idField = element.fields
        .singleWhere((FieldElement f) => f.name == entity.idProperty.name);
    if (idField.setter == null) {
      if (!entity.idProperty.hasFlag(OBXPropertyFlags.ID_SELF_ASSIGNABLE)) {
        throw InvalidGenerationSourceError(
            "Entity ${entity.name} has an ID field '${idField.name}' that is "
            'not assignable (that usually means it is declared final). '
            "This won't work because ObjectBox needs to be able to assign "
            'an ID after inserting a new object (if the given ID was zero). '
            'If you want to assign IDs manually instead, you can annotate the '
            "field '${idField.name}' with `@Id(assignable: true)`. Otherwise "
            'please provide a setter or remove the `final` keyword.');
      } else {
        // We need to get the information to code generator (code_chunks.dart).
        entity.idProperty.fieldIsReadOnly = true;
      }
    }

    // Verify there is at most 1 unique property with REPLACE strategy.
    ensureSingleUniqueReplace(entity);
    // If sync enabled, verify all unique properties use REPLACE strategy.
    ifSyncEnsureAllUniqueAreReplace(entity);

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
            'entity ${entity.name}: ID property not found - either define'
            ' an integer field named ID/id/... (case insensitive) or add'
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

    final indexAnnotation = _indexChecker.firstAnnotationOfExact(f);
    final uniqueAnnotation = _uniqueChecker.firstAnnotationOfExact(f);
    if (indexAnnotation == null && uniqueAnnotation == null) return null;

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

    if (uniqueAnnotation != null && !uniqueAnnotation.isNull) {
      prop.flags |= OBXPropertyFlags.UNIQUE;
      // Determine unique conflict resolution.
      final onConflictVal =
          enumValueItem(uniqueAnnotation.getField('onConflict')!);
      if (onConflictVal != null &&
          ConflictStrategy.values[onConflictVal] == ConflictStrategy.replace) {
        prop.flags |= OBXPropertyFlags.UNIQUE_ON_CONFLICT_REPLACE;
      }
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

  void ensureSingleUniqueReplace(ModelEntity entity) {
    final uniqueReplaceProps = entity.properties
        .where((p) => p.hasFlag(OBXPropertyFlags.UNIQUE_ON_CONFLICT_REPLACE));
    if (uniqueReplaceProps.length > 1) {
      throw InvalidGenerationSourceError(
          "ConflictStrategy.replace can only be used on a single property, but found multiple in '${entity.name}':\n  ${uniqueReplaceProps.join('\n  ')}");
    }
  }

  void ifSyncEnsureAllUniqueAreReplace(ModelEntity entity) {
    if (!entity.hasFlag(OBXEntityFlags.SYNC_ENABLED)) return;
    final uniqueButNotReplaceProps = entity.properties.where((p) {
      return p.hasFlag(OBXPropertyFlags.UNIQUE) &&
          !p.hasFlag(OBXPropertyFlags.UNIQUE_ON_CONFLICT_REPLACE);
    });
    if (uniqueButNotReplaceProps.isNotEmpty) {
      throw InvalidGenerationSourceError(
          "Synced entities must use @Unique(onConflict: ConflictStrategy.replace) on all unique properties, but found others in '${entity.name}':\n  ${uniqueButNotReplaceProps.join('\n  ')}");
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
      var info = StringBuffer(param.name);
      if (param.isRequiredPositional) info.write(' positional');
      if (param.isOptionalPositional) info.write(' optional');
      if (param.isRequiredNamed) info.write(' required-named');
      if (param.isOptionalNamed) info.write(' optional-named');
      info.writeAll([' ', param.type]);
      return info.toString();
    }).toList(growable: false);
  }

  // To support apps that don't yet use null-safety (depend on an older SDK),
  // we generate code without null-safety operators.
  bool nullSafetyEnabled(Element element) {
    final sdk = element.library!.languageVersion.effective;
    return sdk.major > 2 || (sdk.major == 2 && sdk.minor >= 12);
  }
}

extension _TypeCheckerExtensions on TypeChecker {
  void runIfMatches(Element element, void Function(DartObject) fn) {
    final annotations = annotationsOfExact(element);
    if (annotations.isNotEmpty) fn(annotations.first);
  }
}
