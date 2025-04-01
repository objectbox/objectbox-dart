import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:objectbox/internal.dart';
import 'package:objectbox/objectbox.dart';
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
  final _hnswChecker = const TypeChecker.fromRuntime(HnswIndex);

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
      Element classElement, ConstantReader annotation) {
    if (classElement is! ClassElement) {
      throw InvalidGenerationSourceError(
          "Entity '${classElement.name}': annotated element must be a class.");
    }

    // process basic entity (note that allModels.createEntity is not used, as the entity will be merged)
    final entityUid = annotation.read('uid');
    final entityRealClass = annotation.read('realClass');
    final entity = ModelEntity.create(
        IdUid(0, entityUid.isNull ? 0 : entityUid.intValue),
        entityRealClass.isNull
            ? classElement.name
            : entityRealClass.typeValue.element!.name!,
        null,
        uidRequest: !entityUid.isNull && entityUid.intValue == 0);

    // Sync: check if enabled and options
    _syncChecker.runIfMatches(classElement, (annotation) {
      entity.flags |= OBXEntityFlags.SYNC_ENABLED;
      if (annotation.getField('sharedGlobalIds')!.toBoolValue()!) {
        entity.flags |= OBXEntityFlags.SHARED_GLOBAL_IDS;
      }
    });

    log.info(entity);

    entity.constructorParams = constructorParams(findConstructor(classElement));

    // Make sure all stored fields are writable when reading object from DB.
    // Let's filter read-only fields, i.e those that:
    //   * don't have a setter, and
    //   * don't have a corresponding argument in the constructor.
    // Note: `.correspondingSetter == null` is also true for `final` fields.
    final readOnlyFields = <String>{};
    for (var f in classElement.accessors) {
      if (f.isGetter &&
          f.correspondingSetter == null &&
          !entity.constructorParams
              .any((String param) => param.startsWith('${f.name} '))) {
        readOnlyFields.add(f.name);
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
        log.info("  Skipping property '${f.name}': annotated with @Transient.");
        continue;
      }

      if (readOnlyFields.contains(f.name) && !isRelationField(f)) {
        log.info("  Skipping property '${f.name}': is read-only/getter.");
        continue;
      }

      if (f.isPrivate) {
        log.info("  Skipping property '${f.name}': is private.");
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
          fieldType = detectObjectBoxType(f, classElement.name);
          if (fieldType == null) {
            log.warning(
                "  Skipping property '${f.name}': type '${f.type}' not supported,"
                " consider creating a relation for @Entity types (https://docs.objectbox.io/relations),"
                " or replace with getter/setter converting to a supported type (https://docs.objectbox.io/advanced/custom-types).");
            continue;
          }
        }
      }

      String? relTargetName;
      if (isRelationField(f)) {
        if (f.type is! ParameterizedType) {
          log.severe("  Skipping property '${f.name}': invalid relation type, "
              "use a type like ToOne<TargetEntity> or ToMany<TargetEntity>.");
          continue;
        }
        relTargetName =
            (f.type as ParameterizedType).typeArguments[0].element!.name;
      }

      final backlinkAnnotations =
          _backlinkChecker.annotationsOfExact(annotated);
      if (backlinkAnnotations.isNotEmpty) {
        if (!isToManyRel) {
          log.severe(
              "  Skipping property '${f.name}': @Backlink() may only be used with ToMany.");
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
        processAnnotationIndexUnique(
            f, annotated, fieldType, classElement, prop);

        // Vector database: check for any HNSW index params
        _hnswChecker.runIfMatches(annotated, (annotation) {
          // Note: using other index annotations on FloatVector currently
          // errors, so no need to integrate with regular index processing.
          if (fieldType != OBXPropertyType.FloatVector) {
            throw InvalidGenerationSourceError(
                "'${classElement.name}.${f.name}': @HnswIndex is only supported for float vector properties.",
                element: f);
          }
          // Create an index
          prop.flags |= OBXPropertyFlags.INDEXED;
          _readHnswIndexParams(annotation, prop);
        });

        // for code generation
        prop.dartFieldType =
            f.type.element!.name! + (isNullable(f.type) ? '?' : '');
        entity.properties.add(prop);
      }
    }

    processIdProperty(entity, classElement);

    // We need to check that the ID field is writable. Otherwise, generated code
    // for `setId()` won't compile. The only exception is when user uses
    // self-assigned IDs, then a different setter will be generated - one that
    // checks the ID being set is already the same, otherwise it must throw.
    final idField = classElement.fields
        .singleWhere((FieldElement f) => f.name == entity.idProperty.name);
    if (idField.setter == null) {
      if (!entity.idProperty.hasFlag(OBXPropertyFlags.ID_SELF_ASSIGNABLE)) {
        throw InvalidGenerationSourceError(
            "@Id field '${idField.name}' must be writable:"
            " ObjectBox uses it to set the assigned ID after inserting a new object,"
            " provide a setter or remove the 'final' keyword."
            " If your code needs to assign IDs itself,"
            " see https://docs.objectbox.io/advanced/object-ids#self-assigned-object-ids.",
            element: idField);
      } else {
        // We need to get the information to code generator (code_chunks.dart).
        entity.idProperty.fieldIsReadOnly = true;
      }
    }

    // Verify there is at most 1 unique property with REPLACE strategy.
    ensureSingleUniqueReplace(entity, classElement);
    // If sync enabled, verify all unique properties use REPLACE strategy.
    ifSyncEnsureAllUniqueAreReplace(entity, classElement);

    for (var p in entity.properties) {
      log.info('  $p');
    }

    return entity;
  }

  /// For fields that do not have a [Property.type] declared in their [Property]
  /// annotation tries to determine the ObjectBox database type based on the
  /// Dart type. May return null if no supported type is detected.
  int? detectObjectBoxType(FieldElement f, String className) {
    final dartType = f.type;

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
      }
    } else if (['Int8List', 'Uint8List'].contains(dartType.element!.name)) {
      return OBXPropertyType.ByteVector;
    } else if (['Int16List', 'Uint16List'].contains(dartType.element!.name)) {
      return OBXPropertyType.ShortVector;
    } else if (['Int32List', 'Uint32List'].contains(dartType.element!.name)) {
      return OBXPropertyType.IntVector;
    } else if (['Int64List', 'Uint64List'].contains(dartType.element!.name)) {
      return OBXPropertyType.LongVector;
    } else if (dartType.element!.name == 'Float32List') {
      return OBXPropertyType.FloatVector;
    } else if (dartType.element!.name == 'Float64List') {
      return OBXPropertyType.DoubleVector;
    } else if (dartType.element!.name == 'DateTime') {
      log.warning(
          "  DateTime property '${f.name}' in entity '$className' is stored and read using millisecond precision. "
          'To silence this warning, add an explicit type using @Property(type: PropertyType.date) or @Property(type: PropertyType.dateNano) annotation.');
      return OBXPropertyType.Date;
    } else if (isToOneRelationField(f)) {
      return OBXPropertyType.Relation;
    }

    // No supported Dart type recognized.
    return null;
  }

  void processIdProperty(ModelEntity entity, ClassElement classElement) {
    // check properties explicitly annotated with @Id()
    final annotated =
        entity.properties.where((p) => p.hasFlag(OBXPropertyFlags.ID));
    if (annotated.length > 1) {
      final names = annotated.map((e) => e.name).join(", ");
      throw InvalidGenerationSourceError(
          "Entity '${entity.name}': multiple fields ($names) annotated with @Id(), there may only be one.",
          element: classElement);
    }

    if (annotated.length == 1) {
      if (annotated.first.type != OBXPropertyType.Long) {
        throw InvalidGenerationSourceError(
            "Entity '${entity.name}': @Id() property must be 'int'."
            " If you need to use other types, see https://docs.objectbox.io/entity-annotations#object-ids-id.",
            element: classElement);
      }
    } else {
      // if there are no annotated props, try to find one by name & type
      final candidates = entity.properties.where((p) =>
          p.name.toLowerCase() == 'id' && p.type == OBXPropertyType.Long);
      if (candidates.length != 1) {
        throw InvalidGenerationSourceError(
            "Entity '${entity.name}': no @Id() property found, add an int field annotated with @Id().",
            element: classElement);
      }
      candidates.first.flags |= OBXPropertyFlags.ID;
    }

    // finally, ensure ID field compatibility with other bindings
    final idProperty =
        entity.properties.singleWhere((p) => p.hasFlag(OBXPropertyFlags.ID));

    // IDs must not be tagged unsigned for compatibility reasons
    idProperty.flags &= ~OBXPropertyFlags.UNSIGNED;
  }

  void processAnnotationIndexUnique(FieldElement f, Element annotatedElement,
      int? fieldType, Element elementBare, ModelProperty prop) {
    IndexType? indexType;

    final indexAnnotation =
        _indexChecker.firstAnnotationOfExact(annotatedElement);
    final uniqueAnnotation =
        _uniqueChecker.firstAnnotationOfExact(annotatedElement);
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
          "Entity '${elementBare.name}': @Index/@Unique is not supported for type '${f.type}' of field '${f.name}'.",
          element: f);
    }

    if (prop.hasFlag(OBXPropertyFlags.ID)) {
      throw InvalidGenerationSourceError(
          "Entity '${elementBare.name}': @Index/@Unique is not supported for @Id field '${f.name}'."
          " IDs are unique by definition and automatically indexed.",
          element: f);
    }

    // If available use index type from annotation.
    if (indexAnnotation != null && !indexAnnotation.isNull) {
      final typeIndex =
          _enumValueIndex(indexAnnotation.getField('type')!, "Index.type");
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
          "Entity '${elementBare.name}': a hash index is not supported for type '${f.type}' of field '${f.name}'",
          element: f);
    }

    if (uniqueAnnotation != null && !uniqueAnnotation.isNull) {
      prop.flags |= OBXPropertyFlags.UNIQUE;
      // Determine unique conflict resolution.
      final onConflictIndex = _enumValueIndex(
          uniqueAnnotation.getField('onConflict')!, "Unique.onConflict");
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

  void ensureSingleUniqueReplace(
      ModelEntity entity, ClassElement classElement) {
    final uniqueReplaceProps = entity.properties
        .where((p) => p.hasFlag(OBXPropertyFlags.UNIQUE_ON_CONFLICT_REPLACE));
    if (uniqueReplaceProps.length > 1) {
      throw InvalidGenerationSourceError(
          "ConflictStrategy.replace can only be used on a single property, but found multiple in '${entity.name}':\n  ${uniqueReplaceProps.join('\n  ')}",
          element: classElement);
    }
  }

  void ifSyncEnsureAllUniqueAreReplace(
      ModelEntity entity, ClassElement classElement) {
    if (!entity.hasFlag(OBXEntityFlags.SYNC_ENABLED)) return;
    final uniqueButNotReplaceProps = entity.properties.where((p) {
      return p.hasFlag(OBXPropertyFlags.UNIQUE) &&
          !p.hasFlag(OBXPropertyFlags.UNIQUE_ON_CONFLICT_REPLACE);
    });
    if (uniqueButNotReplaceProps.isNotEmpty) {
      throw InvalidGenerationSourceError(
          "Synced entities must use @Unique(onConflict: ConflictStrategy.replace) on all unique properties,"
          " but found others in '${entity.name}':\n  ${uniqueButNotReplaceProps.join('\n  ')}",
          element: classElement);
    }
  }

  /// If not null, returns the index of the enum value.
  int? _enumValueIndex(DartObject enumState, String fieldName) {
    if (enumState.isNull) return null;
    // All enum classes implement the Enum interface
    // which has the index property.
    final index = enumState.getField("index")?.toIntValue();
    if (index == null) {
      throw ArgumentError.value(enumState, fieldName,
          "Dart object state does not appear to represent an enum");
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

  void _readHnswIndexParams(DartObject annotation, ModelProperty property) {
    final distanceTypeIndex = _enumValueIndex(
        annotation.getField('distanceType')!, "HnswIndex.distanceType");
    final distanceType = distanceTypeIndex != null
        ? VectorDistanceType.values[distanceTypeIndex]
        : null;

    final hnswRestored = HnswIndex(
        dimensions: annotation.getField('dimensions')!.toIntValue()!,
        neighborsPerNode: annotation.getField('neighborsPerNode')!.toIntValue(),
        indexingSearchCount:
            annotation.getField('indexingSearchCount')!.toIntValue(),
        flags: _HnswFlagsState.fromState(annotation.getField('flags')!),
        distanceType: distanceType,
        reparationBacklinkProbability: annotation
            .getField('reparationBacklinkProbability')!
            .toDoubleValue(),
        vectorCacheHintSizeKB:
            annotation.getField('vectorCacheHintSizeKB')!.toIntValue());
    property.hnswParams = ModelHnswParams.fromAnnotation(hnswRestored);
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
            state.getField('reparationLimitCandidates')!.toBoolValue() ??
                false);
  }
}
