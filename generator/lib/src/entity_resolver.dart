import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:collection/collection.dart';
import 'package:objectbox/internal.dart';
import 'package:objectbox/objectbox.dart';
import 'package:source_gen/source_gen.dart';

/// EntityResolver finds all classes with an @Entity annotation and generates '.objectbox.info' files in build cache.
/// It's using some tools from source_gen but defining its custom builder because source_gen expects only dart code.
class EntityResolver extends Builder {
  static const suffix = '.objectbox.info';
  @override
  final buildExtensions = {
    '.dart': [suffix],
  };

  static const _annotationsPackage = 'objectbox';
  final _entityChecker = const TypeChecker.typeNamed(
    Entity,
    inPackage: _annotationsPackage,
  );
  final _propertyChecker = const TypeChecker.typeNamed(
    Property,
    inPackage: _annotationsPackage,
  );
  final _idChecker = const TypeChecker.typeNamed(
    Id,
    inPackage: _annotationsPackage,
  );
  final _transientChecker = const TypeChecker.typeNamed(
    Transient,
    inPackage: _annotationsPackage,
  );
  final _syncChecker = const TypeChecker.typeNamed(
    Sync,
    inPackage: _annotationsPackage,
  );
  final _uniqueChecker = const TypeChecker.typeNamed(
    Unique,
    inPackage: _annotationsPackage,
  );
  final _indexChecker = const TypeChecker.typeNamed(
    Index,
    inPackage: _annotationsPackage,
  );
  final _backlinkChecker = const TypeChecker.typeNamed(
    Backlink,
    inPackage: _annotationsPackage,
  );
  final _targetIdPropertyChecker = const TypeChecker.typeNamed(
    TargetIdProperty,
    inPackage: _annotationsPackage,
  );
  final _hnswChecker = const TypeChecker.typeNamed(
    HnswIndex,
    inPackage: _annotationsPackage,
  );
  final _externalTypeChecker = const TypeChecker.typeNamed(
    ExternalType,
    inPackage: _annotationsPackage,
  );
  final _externalNameChecker = const TypeChecker.typeNamed(
    ExternalName,
    inPackage: _annotationsPackage,
  );

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final resolver = buildStep.resolver;
    if (!await resolver.isLibrary(buildStep.inputId)) return;
    final libReader = LibraryReader(await buildStep.inputLibrary);

    // generate for all entities
    final entities = <Map<String, dynamic>>[];
    for (var annotatedEl in libReader.annotatedWith(_entityChecker)) {
      entities.add(
        generateForAnnotatedElement(
          annotatedEl.element,
          annotatedEl.annotation,
        ).toMap(),
      );
    }

    if (entities.isEmpty) return;

    final json = JsonEncoder().convert(entities);
    await buildStep.writeAsString(
      buildStep.inputId.changeExtension(suffix),
      json,
    );
  }

  ModelEntity generateForAnnotatedElement(
    Element classElement,
    ConstantReader annotation,
  ) {
    if (classElement is! ClassElement) {
      throw InvalidGenerationSourceError(
        "Entity '${classElement.displayName}': annotated element must be a class.",
      );
    }

    // process basic entity (note that allModels.createEntity is not used, as the entity will be merged)
    final entityUid = annotation.read('uid');
    final entityRealClass = annotation.read('realClass');
    final entity = ModelEntity.create(
      IdUid(0, entityUid.isNull ? 0 : entityUid.intValue),
      entityRealClass.isNull
          ? classElement.displayName
          : entityRealClass.typeValue.element!.displayName,
      null,
      uidRequest: !entityUid.isNull && entityUid.intValue == 0,
    );

    // @ExternalName
    _externalNameChecker.runIfMatches(classElement, (annotation) {
      entity.externalName = _readExternalNameParams(annotation);
    });

    // Sync: check if enabled and options
    _syncChecker.runIfMatches(classElement, (annotation) {
      entity.flags |= OBXEntityFlags.SYNC_ENABLED;
      if (annotation.getField('sharedGlobalIds')!.toBoolValue()!) {
        entity.flags |= OBXEntityFlags.SHARED_GLOBAL_IDS;
      }
    });

    log.info(entity);

    // Note: if there is no unnamed constructor this list will just be empty
    entity.constructorParams = constructorParams(
      classElement.unnamedConstructor,
    );

    // Make sure all stored fields are writable when reading object from DB.
    // Let's filter read-only fields, i.e those that:
    //   * don't have a setter, and
    //   * don't have a corresponding argument in the constructor.
    // Note: the corresponding setter is also null for final fields.
    final readOnlyFields = <String>{};
    for (var f in classElement.getters) {
      if (f.correspondingSetter == null &&
          !entity.constructorParams.any(
            (String param) => param.startsWith('${f.displayName} '),
          )) {
        readOnlyFields.add(f.displayName);
      }
    }

    // read all suitable annotated properties
    for (var f in classElement.fields) {
      // The field might be implicitly defined by a getter, aka it is synthetic
      // and does not exist in code. So always resolve the actual non-synthetic
      // element that exists in code (here a getter) as only it will have any
      // annotations.
      final annotated = f.nonSynthetic;

      if (_transientChecker.hasAnnotationOfExact(annotated)) {
        log.info(
          "  Skipping property '${f.displayName}': annotated with @Transient.",
        );
        continue;
      }

      if (readOnlyFields.contains(f.name) && !isRelationField(f)) {
        log.info(
          "  Skipping property '${f.displayName}': is read-only/getter.",
        );
        continue;
      }

      if (f.isPrivate) {
        log.info("  Skipping property '${f.displayName}': is private.");
        continue;
      }

      var isToManyRel = false;
      int? fieldType;
      var flags = 0;
      int? propUid;

      // Check for @Id annotation
      _idChecker.runIfMatches(annotated, (annotation) {
        flags |= OBXPropertyFlags.ID;
        if (annotation.getField('assignable')!.toBoolValue()!) {
          flags |= OBXPropertyFlags.ID_SELF_ASSIGNABLE;
        }
      });

      // Get info from @Property annotation
      _propertyChecker.runIfMatches(annotated, (annotation) {
        propUid = annotation.getField('uid')!.toIntValue();
        fieldType = propertyTypeFromAnnotation(annotation.getField('type')!);
        if (!annotation.getField('signed')!.toBoolValue()!) {
          flags |= OBXPropertyFlags.UNSIGNED;
        }
      });

      // If type not specified by @Property annotation, try to detect based
      // on Dart type.
      if (fieldType == null) {
        if (isToManyRelationField(f)) {
          isToManyRel = true;
        } else {
          fieldType = detectObjectBoxType(f, classElement.displayName);
          if (fieldType == null) {
            log.warning(
              "  Skipping property '${f.displayName}': type '${f.type}' not supported,"
              " consider creating a relation for @Entity types (https://docs.objectbox.io/relations),"
              " or replace with getter/setter converting to a supported type (https://docs.objectbox.io/advanced/custom-types).",
            );
            continue;
          }
        }
      }

      String? relTargetName;
      if (isRelationField(f)) {
        if (f.type is! ParameterizedType) {
          log.severe(
            "  Skipping property '${f.displayName}': invalid relation type, "
            "use a type like ToOne<TargetEntity> or ToMany<TargetEntity>.",
          );
          continue;
        }
        relTargetName =
            (f.type as ParameterizedType).typeArguments[0].element!.displayName;
      }

      final backlinkAnnotations = _backlinkChecker.annotationsOfExact(
        annotated,
      );
      if (backlinkAnnotations.isNotEmpty) {
        // Handles ToMany based on other ToOne or ToMany relation (backlink)
        if (!isToManyRel) {
          log.severe(
            "  Skipping property '${f.displayName}': @Backlink() may only be used with ToMany.",
          );
          continue;
        }
        final backlinkField =
            backlinkAnnotations.first.getField('to')!.toStringValue()!;
        final backlink = ModelBacklink(
          name: f.displayName,
          srcEntity: relTargetName!,
          srcField: backlinkField,
        );
        entity.backlinks.add(backlink);
        log.info('  $backlink');
      } else if (isToManyRel) {
        // Handles standalone (non backlink) ToMany relation

        // @ExternalType
        int? externalType;
        _externalTypeChecker.runIfMatches(annotated, (annotation) {
          final externalTypeId = _readExternalTypeParams(annotation);
          externalType = externalTypeId;
        });

        // @ExternalName
        String? externalName;
        _externalNameChecker.runIfMatches(annotated, (annotation) {
          externalName = _readExternalNameParams(annotation);
        });

        // create relation
        final rel = ModelRelation.create(
          IdUid(0, propUid ?? 0),
          f.displayName,
          targetName: relTargetName,
          uidRequest: propUid != null && propUid == 0,
          externalName: externalName,
          externalType: externalType,
        );

        entity.relations.add(rel);

        log.info('  $rel');
      } else {
        // Handles regular property including ToOne relation

        // By default, name properties like the field. For ToOne relations,
        // default to naming the property like the ToOne field + Id suffix.
        // If the ToOne field is annotated with @TargetIdProperty use its name
        // value.
        final String propName;
        if (fieldType == OBXPropertyType.Relation) {
          var customName =
              _targetIdPropertyChecker
                  .firstAnnotationOfExact(annotated)
                  ?.getField('name')
                  ?.toStringValue();
          if (customName != null && customName.isNotEmpty) {
            propName = customName;
          } else {
            propName = '${f.displayName}Id';
          }
        } else {
          propName = f.displayName;
        }

        // create property (do not use readEntity.createProperty in order to avoid generating new ids)
        final prop = ModelProperty.create(
          IdUid(0, propUid ?? 0),
          propName,
          fieldType,
          flags: flags,
          entity: entity,
          uidRequest: propUid != null && propUid == 0,
        );

        // ToOne relation
        if (fieldType == OBXPropertyType.Relation) {
          prop.relationField = f.displayName;
          prop.relationTarget = relTargetName;
          prop.flags |= OBXPropertyFlags.INDEXED;
          prop.flags |= OBXPropertyFlags.INDEX_PARTIAL_SKIP_ZERO;
          // IDs must not be tagged unsigned for compatibility reasons
          prop.flags &= ~OBXPropertyFlags.UNSIGNED;
        }

        // Index and unique annotation.
        processAnnotationIndexUnique(
          f,
          annotated,
          fieldType,
          classElement,
          prop,
        );

        // Vector database: check for any HNSW index params
        _hnswChecker.runIfMatches(annotated, (annotation) {
          // Note: using other index annotations on FloatVector currently
          // errors, so no need to integrate with regular index processing.
          if (fieldType != OBXPropertyType.FloatVector) {
            throw InvalidGenerationSourceError(
              "'${classElement.displayName}.${f.displayName}': @HnswIndex is only supported for float vector properties.",
              element: f,
            );
          }
          // Create an index
          prop.flags |= OBXPropertyFlags.INDEXED;
          _readHnswIndexParams(annotation, prop);
        });

        // @ExternalType
        _externalTypeChecker.runIfMatches(annotated, (annotation) {
          final externalTypeId = _readExternalTypeParams(annotation);
          prop.externalType = externalTypeId;
        });

        // @ExternalName
        _externalNameChecker.runIfMatches(annotated, (annotation) {
          prop.externalName = _readExternalNameParams(annotation);
        });

        // for code generation
        prop.dartFieldType =
            f.type.element!.displayName + (isNullable(f.type) ? '?' : '');
        // For Flex properties, store the full type string including generics
        if (fieldType == OBXPropertyType.Flex) {
          // ignore: deprecated_member_use
          prop.dartFieldType = f.type.getDisplayString(withNullability: true);
        }
        entity.properties.add(prop);
      }
    }

    processIdProperty(entity, classElement);

    // We need to check that the ID field is writable. Otherwise, generated code
    // for `setId()` won't compile. The only exception is when user uses
    // self-assigned IDs, then a different setter will be generated - one that
    // checks the ID being set is already the same, otherwise it must throw.
    final idField = classElement.fields.singleWhere(
      (FieldElement f) => f.displayName == entity.idProperty.name,
    );
    if (idField.setter == null) {
      if (!entity.idProperty.hasFlag(OBXPropertyFlags.ID_SELF_ASSIGNABLE)) {
        throw InvalidGenerationSourceError(
          "@Id field '${idField.displayName}' must be writable,"
          " ObjectBox uses it to set the assigned ID after inserting a new object:"
          " provide a setter or remove the 'final' keyword."
          " If your code needs to assign IDs itself,"
          " see https://docs.objectbox.io/advanced/object-ids#self-assigned-object-ids.",
          element: idField,
        );
      } else {
        // We need to get the information to code generator (code_chunks.dart).
        entity.idProperty.fieldIsReadOnly = true;
      }
    }

    _checkNoPropertiesConflictWithRelationProperties(entity, classElement);
    // Verify there is at most 1 unique property with REPLACE strategy.
    _ensureSingleUniqueReplace(entity, classElement);
    // If sync enabled, verify all unique properties use REPLACE strategy.
    _ifSyncEnsureAllUniqueAreReplace(entity, classElement);

    for (var p in entity.properties) {
      log.info('  $p');
    }

    return entity;
  }

  /// For fields that do not have a [Property.type] declared in their [Property]
  /// annotation tries to determine the ObjectBox database type based on the
  /// Dart type. May return null if no supported type is detected.
  int? detectObjectBoxType(FieldElement field, String classDisplayName) {
    final dartType = field.type;

    if (dartType.isDartCoreInt) {
      // Dart: 8 bytes
      // ObjectBox: 8 bytes
      return OBXPropertyType.Long;
    } else if (dartType.isDartCoreString) {
      return OBXPropertyType.String;
    } else if (dartType.isDartCoreBool) {
      // Dart: 1 byte
      // ObjectBox: 1 byte
      return OBXPropertyType.Bool;
    } else if (dartType.isDartCoreDouble) {
      // Dart: 8 bytes
      // ObjectBox: 8 bytes
      return OBXPropertyType.Double;
    } else if (dartType.isDartCoreList) {
      final itemType = listItemType(dartType)!;
      if (itemType.isDartCoreInt) {
        // List<int>
        // Dart: 8 bytes
        // ObjectBox: 8 bytes
        return OBXPropertyType.LongVector;
      } else if (itemType.isDartCoreDouble) {
        // List<double>
        // Dart: 8 bytes
        // ObjectBox: 8 bytes
        return OBXPropertyType.DoubleVector;
      } else if (itemType.isDartCoreString) {
        // List<String>
        return OBXPropertyType.StringVector;
      } else if (itemType is DynamicType ||
          itemType.isDartCoreObject ||
          itemType.element?.displayName == 'Object') {
        // List<dynamic>, List<Object?>, or List<Object>
        return OBXPropertyType.Flex;
      } else if (itemType.isDartCoreMap) {
        // List<Map<String, dynamic/Object?>> - Object not supported (cast issue)
        if (itemType is ParameterizedType &&
            itemType.typeArguments.length == 2) {
          final keyType = itemType.typeArguments[0];
          final valueType = itemType.typeArguments[1];
          if (keyType.isDartCoreString &&
              (valueType is DynamicType ||
                  valueType.isDartCoreObject ||
                  valueType.element?.displayName == 'Object')) {
            return OBXPropertyType.Flex;
          }
        }
      }
    } else if ([
      'Int8List',
      'Uint8List',
    ].contains(dartType.element!.displayName)) {
      return OBXPropertyType.ByteVector;
    } else if ([
      'Int16List',
      'Uint16List',
    ].contains(dartType.element!.displayName)) {
      return OBXPropertyType.ShortVector;
    } else if ([
      'Int32List',
      'Uint32List',
    ].contains(dartType.element!.displayName)) {
      return OBXPropertyType.IntVector;
    } else if ([
      'Int64List',
      'Uint64List',
    ].contains(dartType.element!.displayName)) {
      return OBXPropertyType.LongVector;
    } else if (dartType.element!.displayName == 'Float32List') {
      return OBXPropertyType.FloatVector;
    } else if (dartType.element!.displayName == 'Float64List') {
      return OBXPropertyType.DoubleVector;
    } else if (dartType.element!.displayName == 'DateTime') {
      log.warning(
        "  DateTime property '${field.displayName}' in entity '$classDisplayName' is stored and read using millisecond precision. "
        'To silence this warning, add an explicit type using @Property(type: PropertyType.date) or @Property(type: PropertyType.dateNano) annotation.',
      );
      return OBXPropertyType.Date;
    } else if (isToOneRelationField(field)) {
      return OBXPropertyType.Relation;
    } else if (dartType.isDartCoreMap) {
      // Check for Map<String, dynamic/Object?/Object>
      if (dartType is ParameterizedType && dartType.typeArguments.length == 2) {
        final keyType = dartType.typeArguments[0];
        final valueType = dartType.typeArguments[1];
        // Key must be String
        if (keyType.isDartCoreString) {
          // Value must be dynamic or Object (nullable or not)
          if (valueType is DynamicType ||
              valueType.isDartCoreObject ||
              valueType.element?.displayName == 'Object') {
            return OBXPropertyType.Flex;
          }
        }
      }
    }

    // No supported Dart type recognized.
    return null;
  }

  void processIdProperty(ModelEntity entity, ClassElement classElement) {
    // check properties explicitly annotated with @Id()
    final annotated = entity.properties.where(
      (p) => p.hasFlag(OBXPropertyFlags.ID),
    );
    if (annotated.length > 1) {
      final names = annotated.map((e) => e.name).join(", ");
      throw InvalidGenerationSourceError(
        "Entity '${entity.name}': multiple fields ($names) annotated with @Id(), there may only be one.",
        element: classElement,
      );
    }

    if (annotated.length == 1) {
      if (annotated.first.type != OBXPropertyType.Long) {
        throw InvalidGenerationSourceError(
          "Entity '${entity.name}': @Id() property must be 'int'."
          " If you need to use other types, see https://docs.objectbox.io/entity-annotations#object-ids-id.",
          element: classElement,
        );
      }
    } else {
      // if there are no annotated props, try to find one by name & type
      final candidates = entity.properties.where(
        (p) => p.name.toLowerCase() == 'id' && p.type == OBXPropertyType.Long,
      );
      if (candidates.length != 1) {
        throw InvalidGenerationSourceError(
          "Entity '${entity.name}': no @Id() property found, add an int field annotated with @Id().",
          element: classElement,
        );
      }
      candidates.first.flags |= OBXPropertyFlags.ID;
    }

    // finally, ensure ID field compatibility with other bindings
    final idProperty = entity.properties.singleWhere(
      (p) => p.hasFlag(OBXPropertyFlags.ID),
    );

    // IDs must not be tagged unsigned for compatibility reasons
    idProperty.flags &= ~OBXPropertyFlags.UNSIGNED;
  }

  void processAnnotationIndexUnique(
    FieldElement f,
    Element annotatedElement,
    int? fieldType,
    Element elementBare,
    ModelProperty prop,
  ) {
    IndexType? indexType;

    final indexAnnotation = _indexChecker.firstAnnotationOfExact(
      annotatedElement,
    );
    final uniqueAnnotation = _uniqueChecker.firstAnnotationOfExact(
      annotatedElement,
    );
    if (indexAnnotation == null && uniqueAnnotation == null) return;

    // Throw if property type does not support a regular index (value/hash-based)
    if (fieldType == OBXPropertyType.Float ||
        fieldType == OBXPropertyType.Double ||
        fieldType == OBXPropertyType.ByteVector ||
        fieldType == OBXPropertyType.ShortVector ||
        fieldType == OBXPropertyType.CharVector ||
        fieldType == OBXPropertyType.IntVector ||
        fieldType == OBXPropertyType.LongVector ||
        fieldType == OBXPropertyType.FloatVector ||
        fieldType == OBXPropertyType.DoubleVector ||
        fieldType == OBXPropertyType.StringVector) {
      throw InvalidGenerationSourceError(
        "Entity '${elementBare.displayName}': @Index/@Unique is not supported for type '${f.type}' of field '${f.displayName}'.",
        element: f,
      );
    }

    if (prop.hasFlag(OBXPropertyFlags.ID)) {
      throw InvalidGenerationSourceError(
        "Entity '${elementBare.displayName}': @Index/@Unique is not supported for @Id field '${f.displayName}'."
        " IDs are unique by definition and automatically indexed.",
        element: f,
      );
    }

    // If available use index type from annotation.
    if (indexAnnotation != null && !indexAnnotation.isNull) {
      final typeIndex = _enumValueIndex(
        indexAnnotation.getField('type')!,
        "Index.type",
      );
      if (typeIndex != null) indexType = IndexType.values[typeIndex];
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
        "Entity '${elementBare.displayName}': a hash index is not supported for type '${f.type}' of field '${f.displayName}'",
        element: f,
      );
    }

    if (uniqueAnnotation != null && !uniqueAnnotation.isNull) {
      prop.flags |= OBXPropertyFlags.UNIQUE;
      // Determine unique conflict resolution.
      final onConflictIndex = _enumValueIndex(
        uniqueAnnotation.getField('onConflict')!,
        "Unique.onConflict",
      );
      if (onConflictIndex != null &&
          ConflictStrategy.values[onConflictIndex] ==
              ConflictStrategy.replace) {
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
    }
  }

  /// Verifies no regular properties are named like ToOne relation
  /// properties (which are implicitly created and not defined as a Dart field,
  /// so their existence isn't obvious).
  void _checkNoPropertiesConflictWithRelationProperties(
    ModelEntity entity,
    ClassElement classElement,
  ) {
    final relationProps = entity.properties.where((p) => p.isRelation);
    final nonRelationProps = entity.properties.whereNot((p) => p.isRelation);

    for (var relProp in relationProps) {
      var propWithSameName = nonRelationProps.firstWhereOrNull(
        (p) => p.name == relProp.name,
      );
      if (propWithSameName != null) {
        final conflictingField = classElement.fields.firstWhereOrNull(
          (f) => f.displayName == propWithSameName.name,
        );
        throw InvalidGenerationSourceError(
          'Property name conflicts with the target ID property "${relProp.name}" created for the ToOne relation "${relProp.relationField}".'
          ' Rename the property or use @TargetIdProperty on the ToOne to rename the target ID property.',
          element: conflictingField,
        );
      }
    }
  }

  void _ensureSingleUniqueReplace(
    ModelEntity entity,
    ClassElement classElement,
  ) {
    final uniqueReplaceProps = entity.properties.where(
      (p) => p.hasFlag(OBXPropertyFlags.UNIQUE_ON_CONFLICT_REPLACE),
    );
    if (uniqueReplaceProps.length > 1) {
      throw InvalidGenerationSourceError(
        "ConflictStrategy.replace can only be used on a single property, but found multiple in '${entity.name}':\n  ${uniqueReplaceProps.join('\n  ')}",
        element: classElement,
      );
    }
  }

  void _ifSyncEnsureAllUniqueAreReplace(
    ModelEntity entity,
    ClassElement classElement,
  ) {
    if (!entity.hasFlag(OBXEntityFlags.SYNC_ENABLED)) return;
    final uniqueButNotReplaceProps = entity.properties.where((p) {
      return p.hasFlag(OBXPropertyFlags.UNIQUE) &&
          !p.hasFlag(OBXPropertyFlags.UNIQUE_ON_CONFLICT_REPLACE);
    });
    if (uniqueButNotReplaceProps.isNotEmpty) {
      throw InvalidGenerationSourceError(
        "Synced entities must use @Unique(onConflict: ConflictStrategy.replace) on all unique properties,"
        " but found others in '${entity.name}':\n  ${uniqueButNotReplaceProps.join('\n  ')}",
        element: classElement,
      );
    }
  }

  /// If not null, returns the index of the enum value.
  int? _enumValueIndex(DartObject enumState, String fieldName) {
    if (enumState.isNull) return null;
    // All enum classes implement the Enum interface
    // which has the index property.
    final index = enumState.getField("index")?.toIntValue();
    if (index == null) {
      throw ArgumentError.value(
        enumState,
        fieldName,
        "Dart object state does not appear to represent an enum",
      );
    }
    return index;
  }

  // find out @Property(type:) field value - its an enum PropertyType
  int? propertyTypeFromAnnotation(DartObject typeField) {
    final item = _enumValueIndex(typeField, "Property.type");
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

  List<String> constructorParams(ConstructorElement? constructor) {
    if (constructor == null) return List.empty();
    return constructor.formalParameters
        .map((param) {
          var info = StringBuffer(param.displayName);
          if (param.isRequiredPositional) info.write(' positional');
          if (param.isOptionalPositional) info.write(' optional');
          if (param.isRequiredNamed) info.write(' required-named');
          if (param.isOptionalNamed) info.write(' optional-named');
          info.writeAll([' ', param.type]);
          return info.toString();
        })
        .toList(growable: false);
  }

  void _readHnswIndexParams(DartObject annotation, ModelProperty property) {
    final distanceTypeIndex = _enumValueIndex(
      annotation.getField('distanceType')!,
      "HnswIndex.distanceType",
    );
    final distanceType =
        distanceTypeIndex != null
            ? VectorDistanceType.values[distanceTypeIndex]
            : null;

    final hnswRestored = HnswIndex(
      dimensions: annotation.getField('dimensions')!.toIntValue()!,
      neighborsPerNode: annotation.getField('neighborsPerNode')!.toIntValue(),
      indexingSearchCount:
          annotation.getField('indexingSearchCount')!.toIntValue(),
      flags: _HnswFlagsState.fromState(annotation.getField('flags')!),
      distanceType: distanceType,
      reparationBacklinkProbability:
          annotation.getField('reparationBacklinkProbability')!.toDoubleValue(),
      vectorCacheHintSizeKB:
          annotation.getField('vectorCacheHintSizeKB')!.toIntValue(),
    );
    property.hnswParams = ModelHnswParams.fromAnnotation(hnswRestored);
  }

  int _readExternalTypeParams(DartObject annotation) {
    final typeIndex = _enumValueIndex(
      annotation.getField('type')!,
      "ExternalType.type",
    );
    final type =
        typeIndex != null ? ExternalPropertyType.values[typeIndex] : null;
    if (type == null) {
      throw InvalidGenerationSourceError(
        "'type' attribute not specified in @ExternalType annotation",
      );
    }
    return externalTypeToOBXExternalType(type);
  }

  String _readExternalNameParams(DartObject annotation) {
    final name = annotation.getField('name')!.toStringValue();
    if (name == null) {
      throw InvalidGenerationSourceError(
        "'name' attribute not specified in @ExternalName annotation",
      );
    }
    return name;
  }
}

extension _TypeCheckerExtensions on TypeChecker {
  void runIfMatches(Element element, void Function(DartObject) fn) {
    final annotations = annotationsOfExact(element);
    if (annotations.isNotEmpty) fn(annotations.first);
  }
}

extension _HnswFlagsState on HnswFlags {
  static HnswFlags? fromState(DartObject state) {
    if (state.isNull) return null;
    return HnswFlags(
      debugLogs: state.getField('debugLogs')!.toBoolValue() ?? false,
      debugLogsDetailed:
          state.getField('debugLogsDetailed')!.toBoolValue() ?? false,
      vectorCacheSimdPaddingOff:
          state.getField('vectorCacheSimdPaddingOff')!.toBoolValue() ?? false,
      reparationLimitCandidates:
          state.getField('reparationLimitCandidates')!.toBoolValue() ?? false,
    );
  }
}
