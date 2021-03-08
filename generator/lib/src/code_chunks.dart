import 'dart:convert';

import 'package:objectbox/src/modelinfo/index.dart';
import 'package:source_gen/source_gen.dart' show InvalidGenerationSourceError;

class CodeChunks {
  static String objectboxDart(ModelInfo model, List<String> imports) => """
    // GENERATED CODE - DO NOT MODIFY BY HAND
    
    // Currently loading model from "JSON" which always encodes with double quotes
    // ignore_for_file: prefer_single_quotes
    // ignore_for_file: camel_case_types
    
    import 'dart:typed_data';
    
    import 'package:objectbox/objectbox.dart';
    import 'package:objectbox/flatbuffers/flat_buffers.dart' as fb;
    export 'package:objectbox/objectbox.dart'; // so that callers only have to import this file
    import 'package:objectbox/internal.dart'; // generated code can access "internal" functionality
    import '${imports.join("';\n import '")}';
    
    ModelDefinition getObjectBoxModel() {
      final model = ModelInfo.fromMap(${JsonEncoder().convert(model.toMap())}, check: false);
      
      final bindings = <Type, EntityDefinition>{};
      ${model.entities.map((entity) => "bindings[${entity.name}] = ${entityBinding(entity)};").join("\n")} 
      
      return ModelDefinition(model, bindings);
    }
    
    ${model.entities.map((entity) => queryConditionClasses(entity)).join("\n")}
    """;

  static String entityBinding(ModelEntity entity) {
    final name = entity.name;
    return '''
      EntityDefinition<${name}>(
        model: model.getEntityByUid(${entity.id.uid}),
        toOneRelations: ($name object) => ${toOneRelations(entity)},
        toManyRelations: ($name object) => ${toManyRelations(entity)},
        getId: ($name object) => object.${propertyFieldName(entity.idProperty)},
        setId: ($name object, int id) {object.${propertyFieldName(entity.idProperty)} = id;},
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
      final offsetVar = 'offset${propertyFieldName(p)}';
      final fieldName = 'object.${propertyFieldName(p)}';
      final nullIfNull = 'final $offsetVar = $fieldName == null ? null';
      offsets[p.id.id] = offsetVar; // see default case in the switch
      switch (p.type) {
        case OBXPropertyType.String:
          return '$nullIfNull : fbb.writeString($fieldName);';
        case OBXPropertyType.StringVector:
          return '$nullIfNull : fbb.writeList($fieldName.map(fbb.writeString).toList(growable: false));';
        case OBXPropertyType.ByteVector:
          return '$nullIfNull : fbb.writeListInt8($fieldName);';
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
          accessorSuffix = ' ?? 0';
        } else if (p.isRelation) {
          accessorSuffix = '.targetId';
        } else if (p.dartFieldType == 'DateTime') {
          if (p.type == OBXPropertyType.Date) {
            accessorSuffix = '?.millisecondsSinceEpoch';
          } else if (p.type == OBXPropertyType.DateNano) {
            accessorSuffix =
                ' == null ? null : object.${propertyFieldName(p)}.microsecondsSinceEpoch * 1000';
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
      return object.${propertyFieldName(entity.idProperty)} ?? 0;
    }''';
  }

  static String objectFromFB(ModelEntity entity) {
    var lines = <String>[];
    lines.addAll(entity.properties.map((ModelProperty p) {
      String fbReader;
      var readField = () =>
          '${fbReader}.vTableGet(buffer, rootOffset, ${propertyFlatBuffersvTableOffset(p)})';
      switch (p.type) {
        case OBXPropertyType.ByteVector:
          if (['Int8List', 'Uint8List'].contains(p.dartFieldType)) {
            // No need for the eager reader here. We need to call fromList()
            // constructor anyway - there's no Int8List.generate() factory.
            fbReader = 'fb.ListReader<int>(fb.Int8Reader())';
            return '''{
             final list = ${readField()};
             object.${propertyFieldName(p)} = list == null ? null : ${p.dartFieldType}.fromList(list);
           }''';
          } else {
            fbReader = 'EagerListReader<int>(fb.Int8Reader())';
          }
          break;
        case OBXPropertyType.Relation:
          fbReader = 'fb.${_propertyFlatBuffersType[p.type]}Reader()';
          return 'object.${propertyFieldName(p)}.targetId = ${readField()};'
              '\n object.${propertyFieldName(p)}.attach(store);';
        case OBXPropertyType.StringVector:
          fbReader = 'EagerListReader<String>(fb.StringReader())';
          break;
        default:
          fbReader = 'fb.${_propertyFlatBuffersType[p.type]}Reader()';
      }
      if (p.dartFieldType == 'DateTime') {
        if (p.type == OBXPropertyType.Date) {
          return '''{
             final value = ${readField()};
             object.${propertyFieldName(p)} = value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
           }''';
        } else if (p.type == OBXPropertyType.DateNano) {
          return '''{
             final value = ${readField()};
             object.${propertyFieldName(p)} = value == null ? null : DateTime.fromMicrosecondsSinceEpoch((value / 1000).round());
           }''';
        } else {
          throw InvalidGenerationSourceError(
              'Invalid property data type ${p.type} for a DateTime field ${entity.name}.${p.name}');
        }
      }
      return 'object.${propertyFieldName(p)} = ${readField()};';
    }));

    lines.addAll(entity.relations.map((ModelRelation rel) =>
        'InternalToManyAccess.setRelInfo(object.${rel.name}, store, ${relInfo(entity, rel)}, store.box<${entity.name}>());'));

    lines.addAll(entity.backlinks.map((ModelBacklink bl) {
      return 'InternalToManyAccess.setRelInfo(object.${bl.name}, store, ${backlinkRelInfo(entity, bl)}, store.box<${entity.name}>());';
    }));

    return '''(Store store, Uint8List fbData) {
      final buffer = fb.BufferContext.fromBytes(fbData);
      final rootOffset = buffer.derefObject(0);
      
      final object = ${entity.name}();
      ${lines.join('\n')}
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
      'RelInfo<${entity.name}>.toMany(${rel.id.id}, object.${propertyFieldName(entity.idProperty)})';

  static String backlinkRelInfo(ModelEntity entity, ModelBacklink bl) {
    final srcEntity = entity.model.findEntityByName(bl.srcEntity);

    // either of these will be set, based on the source field that matches
    ModelRelation srcRel;
    ModelProperty srcProp;

    if (bl.srcField.isEmpty) {
      final matchingProps = srcEntity.properties
          .where((p) => p.isRelation && p.relationTarget == entity.name);
      final matchingRels =
          srcEntity.relations.where((r) => r.targetId == entity.id);
      final candidatesCount = matchingProps.length + matchingRels.length;
      if (candidatesCount > 1) {
        throw InvalidGenerationSourceError(
            'Ambiguous relation backlink source for ${entity.name}.${bl.name}.'
            ' Matching property: $matchingProps.'
            ' Matching standalone relations: $matchingRels.');
      } else if (matchingProps.isNotEmpty) {
        srcProp = matchingProps.first;
      } else if (matchingRels.isNotEmpty) {
        srcRel = matchingRels.first;
      }
    } else {
      srcProp = srcEntity.findPropertyByName(bl.srcField);
      if (srcProp == null) {
        srcRel = srcEntity.relations
            .firstWhere((r) => r.name == bl.srcField, orElse: () => null);
      }
    }

    if (srcRel != null) {
      return 'RelInfo<${srcEntity.name}>.toManyBacklink('
          '${srcRel.id.id}, object.${propertyFieldName(entity.idProperty)})';
    } else if (srcProp != null) {
      return 'RelInfo<${srcEntity.name}>.toOneBacklink('
          '${srcProp.id.id}, object.${propertyFieldName(entity.idProperty)}, '
          '(${srcEntity.name} srcObject) => srcObject.${propertyFieldName(srcProp)})';
    } else {
      throw InvalidGenerationSourceError(
          'Unknown relation backlink source for ${entity.name}.${bl.name}');
    }
  }

  static String toManyRelations(ModelEntity entity) =>
      '{' +
      entity.relations
          .map((ModelRelation rel) =>
              '${relInfo(entity, rel)}: object.${rel.name}')
          .join(',') +
      entity.backlinks
          .map((ModelBacklink bl) =>
              '${backlinkRelInfo(entity, bl)}: object.${bl.name}')
          .join(',') +
      '}';

  static String _queryConditionBuilder(ModelEntity entity) {
    final ret = <String>[];
    for (var prop in entity.properties) {
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
              'Unsupported property type (${prop.type}): ${entity.name}.${name}');
      }

      var propCode =
          'static final ${propertyFieldName(prop)} = Query${fieldType}Property';
      if (prop.isRelation) {
        propCode += '<${entity.name}, ${prop.relationTarget}>'
            '(targetEntityId: ${entity.model.findEntityByName(prop.relationTarget).id.id}, '
            'sourceEntityId:';
      } else {
        propCode += '(entityId:';
      }
      propCode +=
          '${entity.id.id}, propertyId:${prop.id.id}, obxType:${prop.type});';
      ret.add(propCode);
    }

    for (var rel in entity.relations) {
      final targetEntityName =
          entity.model.findEntityByUid(rel.targetId.uid).name;
      ret.add(
          'static final ${rel.name} = QueryRelationMany<${entity.name}, $targetEntityName>'
          '(sourceEntityId:${entity.id.id}, targetEntityId:${rel.targetId.id}, relationId:${rel.id.id});');
    }
    return ret.join();
  }

  static String queryConditionClasses(ModelEntity entity) {
    // TODO add entity.id check to throw an error Box if the wrong entity.property is used
    return '''
    class ${entity.name}_ {
    ${_queryConditionBuilder(entity)}
    }''';
  }
}
