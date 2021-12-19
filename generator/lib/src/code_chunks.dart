import 'package:build/build.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:objectbox/internal.dart';
import 'package:objectbox/src/modelinfo/index.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:source_gen/source_gen.dart' show InvalidGenerationSourceError;

class CodeChunks {
  static String objectboxDart(
          ModelInfo model, List<String> imports, Pubspec? pubspec) =>
      """
    // GENERATED CODE - DO NOT MODIFY BY HAND

    // ignore_for_file: camel_case_types

    import 'dart:typed_data';

    import 'package:flat_buffers/flat_buffers.dart' as fb;
    import 'package:objectbox/internal.dart'; // generated code can access "internal" functionality
    import 'package:objectbox/objectbox.dart';${pubspec?.obxFlutterImport}

    import '${sorted(imports).join("';\n import '")}';

    export 'package:objectbox/objectbox.dart'; // so that callers only have to import this file

    final _entities = <ModelEntity>[
      ${model.entities.map(createModelEntity).join(',')}
    ];

    /// Open an ObjectBox store with the model declared in this file.
    ${openStore(model, pubspec)}

    /// ObjectBox model definition, pass it to [Store] - Store(getObjectBoxModel())
    ModelDefinition getObjectBoxModel() {
      ${defineModel(model)}

      final bindings = <Type, EntityDefinition>{
        ${model.entities.mapIndexed((i, entity) => "${entity.name}: ${entityBinding(i, entity)}").join(",\n")}
      };

      return ModelDefinition(model, bindings);
    }

    ${model.entities.mapIndexed(_metaClass).join("\n")}
    """;

  static String openStore(ModelInfo model, Pubspec? pubspec) {
    final obxFlutter = pubspec?.hasObxFlutterDependency ?? false;
    final nullableOperator = model.entities.first.nullSafetyEnabled ? '?' : '';
    return '''${obxFlutter ? 'Future<Store>' : 'Store'} openStore(
        {String$nullableOperator directory,
          int$nullableOperator maxDBSizeInKB,
          int$nullableOperator fileMode,
          int$nullableOperator maxReaders,
          bool queriesCaseSensitiveDefault = true,
          String$nullableOperator macosApplicationGroup})${obxFlutter ? ' async' : ''} =>
        Store(getObjectBoxModel(),
            directory: directory${obxFlutter ? ' ?? (await defaultStoreDirectory()).path' : ''},
            maxDBSizeInKB: maxDBSizeInKB,
            fileMode: fileMode,
            maxReaders: maxReaders,
            queriesCaseSensitiveDefault: queriesCaseSensitiveDefault,
            macosApplicationGroup: macosApplicationGroup);
            ''';
  }

  static List<T> sorted<T>(List<T> list) {
    list.sort();
    return list;
  }

  static String defineModel(ModelInfo model) {
    return '''
    final model = ModelInfo(
      entities: _entities,
      lastEntityId: ${createIdUid(model.lastEntityId)},
      lastIndexId: ${createIdUid(model.lastIndexId)},
      lastRelationId: ${createIdUid(model.lastRelationId)},
      lastSequenceId: ${createIdUid(model.lastSequenceId)},
      retiredEntityUids: const ${model.retiredEntityUids},
      retiredIndexUids: const ${model.retiredIndexUids},
      retiredPropertyUids: const ${model.retiredPropertyUids},
      retiredRelationUids: const ${model.retiredRelationUids},
      modelVersion: ${model.modelVersion},
      modelVersionParserMinimum: ${model.modelVersionParserMinimum},
      version: ${model.version});
    ''';
  }

  static String createIdUid(IdUid value) {
    return 'const IdUid(${value.id}, ${value.uid})';
  }

  static String createModelEntity(ModelEntity entity) {
    return '''
    ModelEntity(
      id: ${createIdUid(entity.id)},
      name: '${entity.name}',
      lastPropertyId: ${createIdUid(entity.lastPropertyId)},
      flags: ${entity.flags},
      properties: <ModelProperty>[
        ${entity.properties.map(createModelProperty).join(',')}
      ],
      relations: <ModelRelation>[
        ${entity.relations.map(createModelRelation).join(',')}
      ],
      backlinks: <ModelBacklink>[
        ${entity.backlinks.map(createModelBacklink).join(',')}
      ]
    )
    ''';
  }

  static String createModelProperty(ModelProperty property) {
    var additionalArgs = '';
    if (property.indexId != null && !property.indexId!.isEmpty) {
      additionalArgs += ', indexId: ${createIdUid(property.indexId!)}';
    }
    if (property.relationTarget != null &&
        property.relationTarget!.isNotEmpty) {
      additionalArgs += ", relationTarget: '${property.relationTarget!}'";
    }
    return '''
    ModelProperty(
      id: ${createIdUid(property.id)},
      name: '${property.name}',
      type: ${property.type},
      flags: ${property.flags}
      $additionalArgs
    )
    ''';
  }

  static String createModelRelation(ModelRelation relation) {
    return '''
    ModelRelation(
      id: ${createIdUid(relation.id)},
      name: '${relation.name}',
      targetId: ${createIdUid(relation.targetId)}
    )
    ''';
  }

  static String createModelBacklink(ModelBacklink backlink) {
    return '''
    ModelBacklink(
      name: '${backlink.name}',
      srcEntity: '${backlink.srcEntity}',
      srcField: '${backlink.srcField}'
    )
    ''';
  }

  static String entityBinding(int i, ModelEntity entity) {
    final name = entity.name;
    return '''
      EntityDefinition<$name>(
        model: _entities[$i],
        toOneRelations: ($name object) => ${toOneRelations(entity)},
        toManyRelations: ($name object) => ${toManyRelations(entity)},
        getId: ($name object) => object.${propertyFieldName(entity.idProperty)},
        setId: ($name object, int id) ${setId(entity)},
        objectToFB: ${objectToFB(entity)},
        objectFromFB: ${objectFromFB(entity)}
      )
      ''';
  }

  static String propertyFieldName(ModelProperty property) {
    if (property.isRelation) {
      if (!property.name.endsWith('Id')) {
        throw ArgumentError.value(property.name, 'property.name',
            'Relation property name must end with "Id"');
      }

      return property.name.substring(0, property.name.length - 2);
    }

    return property.name;
  }

  static String setId(ModelEntity entity) {
    if (!entity.idProperty.fieldIsReadOnly) {
      return '{object.${propertyFieldName(entity.idProperty)} = id;}';
    }
    // Note: this is a special case handling read-only IDs with assignable=true.
    // Such ID must already be set, i.e. it could not have been assigned.
    return '''{
      if (object.${propertyFieldName(entity.idProperty)} != id) {
        throw ArgumentError('Field ${entity.name}.${propertyFieldName(entity.idProperty)} is read-only '
        '(final or getter-only) and it was declared to be self-assigned. '
        'However, the currently inserted object (.${propertyFieldName(entity.idProperty)}=\${object.${propertyFieldName(entity.idProperty)}}) '
        "doesn't match the inserted ID (ID \$id). "
        'You must assign an ID before calling [box.put()].');
      }
    }''';
  }

  static String fieldDefaultValue(ModelProperty p) {
    switch (p.fieldType) {
      case 'int':
      case 'double':
        return '0';
      case 'bool':
        return 'false';
      case 'String':
        return "''";
      case 'List':
        return '[]';
      case 'Int8List':
        return 'Int8List(0)';
      case 'Uint8List':
        return 'Uint8List(0)';
      default:
        throw InvalidGenerationSourceError(
            'Cannot figure out default value for field: ${p.fieldType} ${p.name}');
    }
  }

  static String propertyFieldAccess(ModelProperty p, String suffixIfNullable) {
    if (!p.entity!.nullSafetyEnabled && suffixIfNullable == '!') {
      suffixIfNullable = '';
    }
    return propertyFieldName(p) + (p.fieldIsNullable ? suffixIfNullable : '');
  }

  static int propertyFlatBuffersSlot(ModelProperty property) =>
      property.id.id - 1;

  static int propertyFlatBuffersvTableOffset(ModelProperty property) =>
      4 + 2 * propertyFlatBuffersSlot(property);

  static final _propertyFlatBuffersType = <int, String>{
    OBXPropertyType.Bool: 'Bool',
    OBXPropertyType.Byte: 'Int8',
    OBXPropertyType.Short: 'Int16',
    OBXPropertyType.Char: 'Int8',
    OBXPropertyType.Int: 'Int32',
    OBXPropertyType.Long: 'Int64',
    OBXPropertyType.Float: 'Float32',
    OBXPropertyType.Double: 'Float64',
    OBXPropertyType.String: 'String',
    OBXPropertyType.Date: 'Int64',
    OBXPropertyType.Relation: 'Int64',
    OBXPropertyType.DateNano: 'Int64',
  };

  static String objectToFB(ModelEntity entity) {
    // prepare properties that must be defined before the FB table is started
    final offsets = <int, String>{};
    final offsetsCode = entity.properties.map((ModelProperty p) {
      final offsetVar = '${propertyFieldName(p)}Offset';
      var fieldName = 'object.${propertyFieldName(p)}';
      offsets[p.id.id] = offsetVar; // see default case in the switch

      var assignment = 'final $offsetVar = ';
      if (p.fieldIsNullable) {
        assignment += '$fieldName == null ? null : ';
        if (p.entity!.nullSafetyEnabled) fieldName += '!';
      }
      switch (p.type) {
        case OBXPropertyType.String:
          return '$assignment fbb.writeString($fieldName);';
        case OBXPropertyType.StringVector:
          return '$assignment fbb.writeList($fieldName.map(fbb.writeString).toList(growable: false));';
        case OBXPropertyType.ByteVector:
          return '$assignment fbb.writeListInt8($fieldName);';
        default:
          offsets.remove(p.id.id);
          return null;
      }
    }).where((s) => s != null);

    // prepare the remainder of the properties, including those with offsets
    final propsCode = entity.properties.map((ModelProperty p) {
      final fbField = propertyFlatBuffersSlot(p);
      if (offsets.containsKey(p.id.id)) {
        return 'fbb.addOffset($fbField, ${offsets[p.id.id]});';
      } else {
        var accessorSuffix = '';
        if (p == entity.idProperty) {
          // ID must always be present in the flatbuffer
          if (p.fieldIsNullable) accessorSuffix = ' ?? 0';
        } else if (p.isRelation) {
          accessorSuffix = '.targetId';
        } else if (p.fieldType == 'DateTime') {
          if (p.type == OBXPropertyType.Date) {
            if (p.fieldIsNullable) accessorSuffix = '?';
            accessorSuffix += '.millisecondsSinceEpoch';
          } else if (p.type == OBXPropertyType.DateNano) {
            if (p.fieldIsNullable) {
              accessorSuffix =
                  ' == null ? null : object.${propertyFieldName(p)}';
              if (p.entity!.nullSafetyEnabled) accessorSuffix += '!';
            }
            accessorSuffix += '.microsecondsSinceEpoch * 1000';
          }
        }
        return 'fbb.add${_propertyFlatBuffersType[p.type]}($fbField, object.${propertyFieldName(p)}$accessorSuffix);';
      }
    });

    return '''(${entity.name} object, fb.Builder fbb) {
      ${offsetsCode.join('\n')}
      fbb.startTable(${entity.lastPropertyId.id + 1});
      ${propsCode.join('\n')}
      fbb.finish(fbb.endTable());
      return object.${propertyFieldAccess(entity.idProperty, ' ?? 0')};
    }''';
  }

  static String objectFromFB(ModelEntity entity) {
    // collect code for the template at the end of this function
    final constructorLines = <String>[]; // used as constructor arguments
    final cascadeLines = <String>[]; // used with cascade operator (..sth = val)
    final preLines = <String>[]; // code ran before the object is initialized
    final postLines = <String>[]; // code ran after the object is initialized

    // Prepare a "reader" for each field. As a side-effect, create a map from
    // property to its index in entity.properties.
    final fieldIndexes = <String, int>{};
    final fieldReaders =
        entity.properties.mapIndexed((int index, ModelProperty p) {
      fieldIndexes[propertyFieldName(p)] = index;

      String? fbReader;
      var readFieldOrNull = () =>
          'const $fbReader.vTableGetNullable(buffer, rootOffset, ${propertyFlatBuffersvTableOffset(p)})';
      var readFieldNonNull = ([String? defaultValue]) =>
          'const $fbReader.vTableGet(buffer, rootOffset, ${propertyFlatBuffersvTableOffset(p)}, ${defaultValue ?? fieldDefaultValue(p)})';
      var readField =
          () => p.fieldIsNullable ? readFieldOrNull() : readFieldNonNull();
      final valueVar = '${propertyFieldName(p)}Value';

      switch (p.type) {
        case OBXPropertyType.ByteVector:
          if (['Int8List', 'Uint8List'].contains(p.fieldType)) {
            fbReader = 'fb.${p.fieldType}Reader(lazy: false)';
            return '${readField()} as ${p.fieldType}${p.fieldIsNullable && p.entity!.nullSafetyEnabled ? "?" : ""}';
          } else {
            fbReader = 'fb.ListReader<int>(fb.Int8Reader(), lazy: false)';
          }
          break;
        case OBXPropertyType.Relation:
          fbReader = 'fb.${_propertyFlatBuffersType[p.type]}Reader()';
          return readFieldNonNull('0');
        case OBXPropertyType.String:
          // TODO `asciiOptimization: true` is for keeping the same behavior as the previous FB fork.
          //      Check if it still makes sense with the latest Dart/Flutter.
          fbReader = 'fb.StringReader(asciiOptimization: true)';
          break;
        case OBXPropertyType.StringVector:
          // TODO `asciiOptimization: true` is for keeping the same behavior as the previous FB fork.
          //      Check if it still makes sense with the latest Dart/Flutter.
          fbReader =
              'fb.ListReader<String>(fb.StringReader(asciiOptimization: true), lazy: false)';
          break;
        default:
          fbReader = 'fb.${_propertyFlatBuffersType[p.type]}Reader()';
      }
      if (p.fieldType == 'DateTime') {
        if (p.fieldIsNullable) {
          preLines.add('final $valueVar = ${readFieldOrNull()};');
          if (p.type == OBXPropertyType.Date) {
            return '$valueVar == null ? null : DateTime.fromMillisecondsSinceEpoch($valueVar)';
          } else if (p.type == OBXPropertyType.DateNano) {
            return '$valueVar == null ? null : DateTime.fromMicrosecondsSinceEpoch(($valueVar / 1000).round())';
          }
        } else {
          if (p.type == OBXPropertyType.Date) {
            return "DateTime.fromMillisecondsSinceEpoch(${readFieldNonNull('0')})";
          } else if (p.type == OBXPropertyType.DateNano) {
            return "DateTime.fromMicrosecondsSinceEpoch((${readFieldNonNull('0')} / 1000).round())";
          }
        }
        throw InvalidGenerationSourceError(
            'Invalid property data type ${p.type} for a DateTime field ${entity.name}.${p.name}');
      }
      return readField();
    }).toList(growable: false);

    // try to initialize as much as possible using the constructor
    entity.constructorParams.forEachWhile((String declaration) {
      // See [EntityResolver.constructorParams()] for the format.
      final declarationParts = declaration.split(' ');
      final paramName = declarationParts[0];
      final paramType = declarationParts[1];
      final paramDartType = declarationParts[2];

      final index = fieldIndexes[paramName];
      late String paramValueCode;
      if (index != null) {
        paramValueCode = fieldReaders[index];
        if (entity.properties[index].isRelation) {
          if (paramDartType.startsWith('ToOne<')) {
            paramValueCode = 'ToOne(targetId: $paramValueCode)';
          } else if (paramType == 'optional-named') {
            log.info('Skipping constructor parameter $paramName on '
                "'${entity.name}': the matching field is a relation but the type "
                "isn't - don't know how to initialize this parameter.");
            return true;
          }
        }
      } else if (paramDartType.startsWith('ToMany<')) {
        paramValueCode = 'ToMany()';
      } else {
        // If we can't find a positional param, we can't use the constructor at all.
        if (paramType == 'positional' || paramType == 'required-named') {
          throw InvalidGenerationSourceError(
              "Cannot use the default constructor of '${entity.name}': "
              "don't know how to initialize param $paramName - no such property.");
        } else if (paramType == 'optional') {
          // OK, close the constructor, the rest will be initialized separately.
          return false;
        }
        return true; // continue to the next param
      }

      switch (paramType) {
        case 'positional':
        case 'optional':
          constructorLines.add(paramValueCode);
          break;
        case 'required-named':
        case 'optional-named':
          constructorLines.add('$paramName: $paramValueCode');
          break;
        default:
          throw InvalidGenerationSourceError(
              'Invalid constructor parameter type - internal error');
      }

      // Good, we don't need to set this field anymore.
      // Don't remove - that would mess up indexes.
      if (index != null) fieldReaders[index] = '';

      return true;
    });

    // initialize the rest using the cascade operator
    fieldReaders.forEachIndexed((int index, String code) {
      if (code.isNotEmpty && !entity.properties[index].isRelation) {
        cascadeLines
            .add('..${propertyFieldName(entity.properties[index])} = $code');
      }
    });

    // add initializers for relations
    entity.properties.forEachIndexed((int index, ModelProperty p) {
      if (!p.isRelation) return;
      if (fieldReaders[index].isNotEmpty) {
        postLines.add(
            'object.${propertyFieldName(p)}.targetId = ${fieldReaders[index]};');
      }
      postLines.add('object.${propertyFieldName(p)}.attach(store);');
    });

    postLines.addAll(entity.relations.map((ModelRelation rel) =>
        'InternalToManyAccess.setRelInfo(object.${rel.name}, store, ${relInfo(entity, rel)}, store.box<${entity.name}>());'));

    postLines.addAll(entity.backlinks.map((ModelBacklink bl) {
      return 'InternalToManyAccess.setRelInfo(object.${bl.name}, store, ${backlinkRelInfo(entity, bl)}, store.box<${entity.name}>());';
    }));

    return '''(Store store, ByteData fbData) {
      final buffer = fb.BufferContext(fbData);
      final rootOffset = buffer.derefObject(0);
      ${preLines.join('\n')}
      final object = ${entity.name}(${constructorLines.join(', \n')})${cascadeLines.join('\n')};
      ${postLines.join('\n')}
      return object;
    }''';
  }

  static String toOneRelations(ModelEntity entity) =>
      '[' +
      entity.properties
          .where((ModelProperty prop) => prop.isRelation)
          .map((ModelProperty prop) => 'object.${propertyFieldName(prop)}')
          .join(',') +
      ']';

  static String relInfo(ModelEntity entity, ModelRelation rel) =>
      'RelInfo<${entity.name}>.toMany(${rel.id.id}, object.${propertyFieldAccess(entity.idProperty, '!')})';

  static String backlinkRelInfo(ModelEntity entity, ModelBacklink bl) {
    final srcEntity = entity.model.findEntityByName(bl.srcEntity);
    if (srcEntity == null) {
      throw InvalidGenerationSourceError(
          'Invalid relation backlink ${entity.name}.${bl.name} '
          '- source entity ${bl.srcEntity} not found.');
    }

    // either of these will be set, based on the source field that matches
    ModelRelation? srcRel;
    ModelProperty? srcProp;

    final throwAmbiguousError = (String prop, String rel) =>
        throw InvalidGenerationSourceError(
            'Ambiguous relation backlink source for ${entity.name}.${bl.name}.'
            ' Matching property: $prop.'
            ' Matching standalone relation: $rel.');

    if (bl.srcField.isEmpty) {
      final matchingProps = srcEntity.properties
          .where((p) => p.isRelation && p.relationTarget == entity.name);
      final matchingRels =
          srcEntity.relations.where((r) => r.targetId == entity.id);
      final candidatesCount = matchingProps.length + matchingRels.length;
      if (candidatesCount > 1) {
        throwAmbiguousError(matchingProps.toString(), matchingRels.toString());
      } else if (matchingProps.isNotEmpty) {
        srcProp = matchingProps.first;
      } else if (matchingRels.isNotEmpty) {
        srcRel = matchingRels.first;
      }
    } else {
      srcProp = srcEntity.findPropertyByName(bl.srcField + 'Id');
      srcRel =
          srcEntity.relations.firstWhereOrNull((r) => r.name == bl.srcField);

      if (srcProp != null && srcRel != null) {
        throwAmbiguousError(srcProp.toString(), srcRel.toString());
      }
    }

    if (srcRel != null) {
      return 'RelInfo<${srcEntity.name}>.toManyBacklink('
          '${srcRel.id.id}, object.${propertyFieldAccess(entity.idProperty, '!')})';
    } else if (srcProp != null) {
      return 'RelInfo<${srcEntity.name}>.toOneBacklink('
          '${srcProp.id.id}, object.${propertyFieldAccess(entity.idProperty, '!')}, '
          '(${srcEntity.name} srcObject) => srcObject.${propertyFieldName(srcProp)})';
    } else {
      throw InvalidGenerationSourceError(
          'Unknown relation backlink source for ${entity.name}.${bl.name}');
    }
  }

  static String toManyRelations(ModelEntity entity) {
    final definitions = <String>[];
    definitions.addAll(entity.relations.map(
        (ModelRelation rel) => '${relInfo(entity, rel)}: object.${rel.name}'));
    definitions.addAll(entity.backlinks.map((ModelBacklink bl) =>
        '${backlinkRelInfo(entity, bl)}: object.${bl.name}'));
    return '{${definitions.join(',')}}';
  }

  static String _metaClass(int i, ModelEntity entity) {
    final fields = <String>[];
    for (var p = 0; p < entity.properties.length; p++) {
      final prop = entity.properties[p];
      final name = prop.name;

      // see OBXPropertyType
      String fieldType;
      switch (prop.type) {
        case OBXPropertyType.Bool:
          fieldType = 'Boolean';
          break;
        case OBXPropertyType.String:
          fieldType = 'String';
          break;
        case OBXPropertyType.Float:
        case OBXPropertyType.Double:
          fieldType = 'Double';
          break;
        case OBXPropertyType.Byte:
        case OBXPropertyType.Short:
        case OBXPropertyType.Char:
        case OBXPropertyType.Int:
        case OBXPropertyType.Long:
        case OBXPropertyType.Date:
        case OBXPropertyType.DateNano:
          fieldType = 'Integer';
          break;
        case OBXPropertyType.Relation:
          fieldType = 'Relation';
          break;
        case OBXPropertyType.ByteVector:
          fieldType = 'ByteVector';
          break;
        case OBXPropertyType.StringVector:
          fieldType = 'StringVector';
          break;
        default:
          throw InvalidGenerationSourceError(
              'Unsupported property type (${prop.type}): ${entity.name}.$name');
      }

      var propCode = '''
        /// see [${entity.name}.${propertyFieldName(prop)}]
        static final ${propertyFieldName(prop)} = ''';
      if (prop.isRelation) {
        propCode +=
            'QueryRelationToOne<${entity.name}, ${prop.relationTarget}>';
      } else {
        propCode += 'Query${fieldType}Property<${entity.name}>';
      }
      propCode += '(_entities[$i].properties[$p]);';
      fields.add(propCode);
    }

    for (var r = 0; r < entity.relations.length; r++) {
      final rel = entity.relations[r];
      final targetEntityName =
          entity.model.findEntityByUid(rel.targetId.uid)!.name;
      fields.add('''
          /// see [${entity.name}.${rel.name}]
          static final ${rel.name} = QueryRelationToMany'''
          '<${entity.name}, $targetEntityName>(_entities[$i].relations[$r]);');
    }

    return '''
      /// [${entity.name}] entity fields to define ObjectBox queries.
      class ${entity.name}_ {${fields.join()}}
    ''';
  }
}

extension _Pubspec on Pubspec {
  static final infixes = ['', '_sync'];

  static String depPackage(String infix) => 'objectbox${infix}_flutter_libs';

  String get obxFlutterImport {
    for (var i = 0; i < infixes.length; i++) {
      final dep = depPackage(infixes[i]);
      if (dependencies[dep] != null) {
        return "\nimport 'package:$dep/$dep.dart';";
      }
    }
    return '';
  }

  bool get hasObxFlutterDependency =>
      infixes.any((infix) => dependencies[depPackage(infix)] != null);
}
