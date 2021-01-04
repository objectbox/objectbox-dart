import 'dart:convert';
import 'package:objectbox/src/modelinfo/index.dart';
import 'package:objectbox/src/bindings/bindings.dart';
import 'package:source_gen/source_gen.dart' show InvalidGenerationSourceError;

class CodeChunks {
  static String objectboxDart(ModelInfo model, List<String> imports) => """
    // GENERATED CODE - DO NOT MODIFY BY HAND
    
    // Currently loading model from "JSON" which always encodes with double quotes
    // ignore_for_file: prefer_single_quotes
    ${typedDataImportIfNeeded(model)}
    import 'package:objectbox/objectbox.dart';
    export 'package:objectbox/objectbox.dart'; // so that callers only have to import this file
    import '${imports.join("';\n import '")}';
    
    ModelDefinition getObjectBoxModel() {
      final model = ModelInfo.fromMap(${JsonEncoder().convert(model.toMap())}, check: false);
      
      final bindings = <Type, EntityDefinition>{};
      ${model.entities.map((entity) => "bindings[${entity
      .name}] = ${entityBinding(entity)};").join("\n")} 
      
      return ModelDefinition(model, bindings);
    }
    
    ${model.entities.map((entity) => queryConditionClasses(entity)).join("\n")}
    """;

  static String entityBinding(ModelEntity entity) {
    final name = entity.name;
    return """
      EntityDefinition<${name}>(
        model: model.getEntityByUid(${entity.id.uid}),
        toOneRelations: ($name inst) => [${toOneRelationsList(entity).join(',')}],
        getId: ($name inst) => inst.${propertyFieldName(entity.idProperty)},
        setId: ($name inst, int id) {inst.${propertyFieldName(
        entity.idProperty)} = id;},
        reader: ($name inst) => {
          ${entity.properties.map(propertyReader).join(",\n")}
        },
        writer: (Store store, Map<String, dynamic> members) {
          final r = $name();
          ${entity.properties.map(propertyWriter).join()}
          return r;
        }
      )
      """;
  }

  static String typedDataImportIfNeeded(ModelInfo model) {
    if (model.entities
        .any((ModelEntity entity) => entity.properties.any(isTypedDataList))) {
      return "import 'dart:typed_data';\n";
    }
    return '';
  }

  static bool isTypedDataList(ModelProperty property) {
    return ['Int8List', 'Uint8List'].contains(property.dartFieldType);
  }

  static String propertyFieldName(ModelProperty property) {
    if (property.type == OBXPropertyType.Relation) {
      if (!property.name.endsWith('Id')) {
        throw ArgumentError.value(property.name, 'property.name',
            'Relation property name must end with "Id"');
      }

      return property.name.substring(0, property.name.length - 2);
    }

    return property.name;
  }

  static String propertyReader(ModelProperty property) {
    if (property.type == OBXPropertyType.Relation) {
      return "'${property.name}': inst.${propertyFieldName(property)}.targetId";
    } else {
      return "'${property.name}': inst.${propertyFieldName(property)}";
    }
  }

  static String propertyWriter(ModelProperty property) {
    final name = property.name;
    final field = propertyFieldName(property);
    if (isTypedDataList(property)) {
      return "r.$field = members['${name}'] == null ? null : ${property
          .dartFieldType}.fromList(members['${name}']);";
    } else if (property.type == OBXPropertyType.Relation) {
      return "r.$field.targetId = members['${name}'];" +
          "\n r.$field.attach(store);";
    } else {
      return "r.$field = members['${name}'];";
    }
  }

  static List<String> toOneRelationsList(ModelEntity entity) =>
      entity.properties
          .where((ModelProperty prop) => prop.type == OBXPropertyType.Relation)
          .map((ModelProperty prop) => "inst.${propertyFieldName(prop)}")
          .toList(growable: false);

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
              'Unsupported property type (${prop.type}): ${entity
                  .name}.${name}');
      }

      final relationTypeGenericParam = prop.type == OBXPropertyType.Relation
          ? '<${prop.relationTarget}>'
          : '';

      ret.add('''
        static final ${propertyFieldName(
          prop)} = Query${fieldType}Property$relationTypeGenericParam(entityId:${entity
          .id.id}, propertyId:${prop.id.id}, obxType:${prop.type});
        ''');
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
