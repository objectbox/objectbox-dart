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
    import 'package:objectbox/flatbuffers/flat_buffers.dart' as fb;
    export 'package:objectbox/objectbox.dart'; // so that callers only have to import this file
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
    return """
      EntityDefinition<${name}>(
        model: model.getEntityByUid(${entity.id.uid}),
        getId: ($name inst) => inst.${propertyFieldName(entity.idProperty)},
        setId: ($name inst, int id) {inst.${propertyFieldName(entity.idProperty)} = id;},
        objectToFB: ${objectToFB(entity)},
        writer: (Map<String, dynamic> members) {
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
    return property.name;
  }

  static final _propertyFlatBuffersType = <int, String>{
    OBXPropertyType.Bool: 'Bool',
    OBXPropertyType.Byte: 'Uint8',
    OBXPropertyType.Short: 'Int16',
    OBXPropertyType.Char: 'Int8',
    OBXPropertyType.Int: 'Int32',
    OBXPropertyType.Long: 'Int64',
    OBXPropertyType.Float: 'Float32',
    OBXPropertyType.Double: 'Float64',
    OBXPropertyType.Date: 'Int64',
    OBXPropertyType.Relation: 'Int64',
    OBXPropertyType.DateNano: 'Int64',
  };

  static String objectToFB(ModelEntity entity) {
    // prepare properties that must be defined before the FB table is started
    final offsets = <int, String>{};
    final offsetsCode = entity.properties.map((ModelProperty p) {
      final offsetVar = 'offset${propertyFieldName(p)}';
      final fieldName = 'inst.${propertyFieldName(p)}';
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
      final fbField = p.id.id - 1;
      if (offsets.containsKey(p.id.id)) {
        return 'fbb.addOffset($fbField, ${offsets[p.id.id]});';
      } else {
        // ID must always be present in the flatbuffer
        final valueIfNull = (p == entity.idProperty) ? ' ?? 0' : '';
        return 'fbb.add${_propertyFlatBuffersType[p.type]}($fbField, inst.${propertyFieldName(p)}$valueIfNull);';
      }
    });

    return '''(${entity.name} inst, fb.Builder fbb) {
      ${offsetsCode.join('\n')}
      fbb.startTable();
      ${propsCode.join('\n')}
      fbb.finish(fbb.endTable());
      return inst.${propertyFieldName(entity.idProperty)} ?? 0;
    }''';
  }

  static String propertyWriter(ModelProperty property) {
    final name = property.name;
    if (isTypedDataList(property)) {
      return "r.${propertyFieldName(property)} = members['${name}'] == null ? null : ${property.dartFieldType}.fromList(members['${name}']);";
    } else {
      return "r.${propertyFieldName(property)} = members['${name}'];";
    }
  }

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
        case OBXPropertyType.Relation:
          fieldType = 'Integer';
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

      ret.add('''
    static final ${prop.name} = Query${fieldType}Property(entityId:${entity.id.id}, propertyId:${prop.id.id}, obxType:${prop.type});
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
