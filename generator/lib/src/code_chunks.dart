import "dart:convert";
import "package:objectbox/src/modelinfo/index.dart";
import "package:objectbox/src/bindings/constants.dart" show OBXPropertyType;
import "package:source_gen/source_gen.dart" show InvalidGenerationSourceError;

class CodeChunks {
  static String objectboxDart(ModelInfo model, List<String> imports) => """
    // GENERATED CODE - DO NOT MODIFY BY HAND
    
    import 'package:objectbox/objectbox.dart';
    export 'package:objectbox/objectbox.dart'; // so that callers only have to import this file
    import '${imports.join("';\n import '")}';
    
    ModelDefinition getObjectBoxModel() {
      final model = ModelInfo.fromMap(${JsonEncoder().convert(model.toMap(forCodeGen: true))}, check: false);
      
      final bindings = Map<Type, EntityDefinition>();
      ${model.entities.map((entity) => "bindings[${entity.name}] = ${entityBinding(entity)};").join("\n")} 
      
      return ModelDefinition(model, bindings);
    }
    
    ${model.entities.map((entity) => queryConditionClasses(entity)).join("\n")}
    """;

  static String entityBinding(ModelEntity entity) {
    String name = entity.name;
    return """
      EntityDefinition<${name}>(
        model: model.findEntityByUid(${entity.id.uid}),
        reader: ($name inst) => {
          ${entity.properties.map((p) => "\"${p.name}\": inst.${p.name}").join(",\n")}
        },
        writer: (Map<String, dynamic> members) {
          $name r = $name();
          ${entity.properties.map((p) => "r.${p.name} = members[\"${p.name}\"];").join()}
          return r;
        }
      )
      """;
  }

  static String _queryConditionBuilder(ModelEntity entity) {
    final ret = <String>[];
    for (var prop in entity.properties) {
      final name = prop.name;

      // see OBXPropertyType
      String fieldType;
      switch (prop.type) {
        case OBXPropertyType.Bool:
          fieldType = "Boolean";
          break;
        case OBXPropertyType.String:
          fieldType = "String";
          break;
        float:
        case OBXPropertyType.Double:
          fieldType = "Double";
          break;
        case OBXPropertyType.Float:
          continue float;
        integer:
        case OBXPropertyType.Int:
          fieldType = "Integer";
          break;
        case OBXPropertyType.Byte:
          continue integer;
        case OBXPropertyType.Short:
          continue integer;
        case OBXPropertyType.Char:
          continue integer;
        case OBXPropertyType.Long:
          continue integer;
        default:
          throw InvalidGenerationSourceError("Unsupported property type (${prop.type}): ${entity.name}.${name}");
      }

      ret.add("""
        static final ${name} = Query${fieldType}Property(entityId:${entity.id.id}, propertyId:${prop.id.id}, obxType:${prop.type});
        """);
    }
    return ret.join();
  }

  static String queryConditionClasses(ModelEntity entity) {
    // TODO add entity.id check to throw an error Box if the wrong entity.property is used
    return """
    class ${entity.name}_ {
      ${_queryConditionBuilder(entity)}
    }""";
  }
}
