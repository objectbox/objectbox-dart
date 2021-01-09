import 'dart:convert';
import 'package:objectbox/src/modelinfo/index.dart';
import 'package:objectbox/src/bindings/bindings.dart';
import 'package:source_gen/source_gen.dart' show InvalidGenerationSourceError;

class CodeChunks {
  static String objectboxDart(ModelInfo model, List<String> imports) => """
    // GENERATED CODE - DO NOT MODIFY BY HAND
    
    // Currently loading model from "JSON" which always encodes with double quotes
    // ignore_for_file: prefer_single_quotes
    
    import 'dart:typed_data';
    
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
        objectFromFB: ${objectFromFB(entity)}
      )
      """;
  }

  static String propertyFieldName(ModelProperty property) {
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
      final fbField = propertyFlatBuffersSlot(p);
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

  static String objectFromFB(ModelEntity entity) {
    final propsCode = entity.properties.map((ModelProperty p) {
      String fbReader;
      switch (p.type) {
        case OBXPropertyType.ByteVector:
          fbReader = 'fb.ListReader<int>(fb.Int8Reader())';
          if (['Int8List', 'Uint8List'].contains(p.dartFieldType)) {
            return '''{
             final list = ${fbReader}.vTableGet(buffer, rootOffset, ${propertyFlatBuffersvTableOffset(p)});
             object.${propertyFieldName(p)} = list == null ? null : ${p.dartFieldType}.fromList(list);
           }''';
          }
          break;
        case OBXPropertyType.StringVector:
          fbReader = 'fb.ListReader<String>(fb.StringReader())';
          break;
        default:
          fbReader = 'fb.${_propertyFlatBuffersType[p.type]}Reader()';
      }
      return 'object.${propertyFieldName(p)} = ${fbReader}.vTableGet(buffer, rootOffset, ${propertyFlatBuffersvTableOffset(p)});';
    });

    return '''(Uint8List fbData) {
      final buffer = fb.BufferContext.fromBytes(fbData);
      final rootOffset = buffer.derefObject(0);
      
      final object = ${entity.name}();
      ${propsCode.join('\n')}
      return object;
    }''';
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
