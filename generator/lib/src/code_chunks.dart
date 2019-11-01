import "package:objectbox/src/modelinfo/index.dart";
import "package:objectbox/src/bindings/constants.dart" show OBXPropertyType;
import "package:source_gen/source_gen.dart" show InvalidGenerationSourceError;

class CodeChunks {
  static String modelInfoLoader() => """
      Map<int, ModelEntity> _allOBXModelEntities;

      void _loadOBXModelEntities() {
        _allOBXModelEntities = {};
        ModelInfo modelInfo = ModelInfo.fromMap(||MODEL-JSON||);
        modelInfo.entities.forEach((e) => _allOBXModelEntities[e.id.uid] = e);
      }

      ModelEntity _getOBXModelEntity(int entityUid) {
        if (_allOBXModelEntities == null) _loadOBXModelEntities();
        if (!_allOBXModelEntities.containsKey(entityUid)) {
            throw Exception("entity uid missing in objectbox-model.json: \$entityUid");
        }
        return _allOBXModelEntities[entityUid];
      }
    """;

  static String instanceBuildersReaders(ModelEntity readEntity) {
    String name = readEntity.name;
    return """
        ModelEntity _${name}_OBXModelGetter() {
          return _getOBXModelEntity(${readEntity.id.uid});
        }

        $name _${name}_OBXBuilder(Map<String, dynamic> members) {
          $name r = $name();
          ${readEntity.properties.map((p) => "r.${p.name} = members[\"${p.name}\"];").join()}
          return r;
        }

        Map<String, dynamic> _${name}_OBXReader($name inst) {
          Map<String, dynamic> r = {};
          ${readEntity.properties.map((p) => "r[\"${p.name}\"] = inst.${p.name};").join()}
          return r;
        }

        const ${name}_OBXDefs = EntityDefinition<${name}>(_${name}_OBXModelGetter, _${name}_OBXReader, _${name}_OBXBuilder);
      """;
  }

  static String _queryConditionBuilder(ModelEntity readEntity) {
    final ret = <String>[];
    for (var f in readEntity.properties) {
      final name = f.name;

      // see OBXPropertyType
      String fieldType;
      switch (f.type) {
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
          throw InvalidGenerationSourceError("Unsupported property type (${f.type}): ${readEntity.name}.${name}");
      }

      ret.add("""
        static final ${name} = Query${fieldType}Property(entityId:${readEntity.id.id}, propertyId:${f.id.id}, obxType:${f.type});
        """);
    }
    return ret.join();
  }

  static String queryConditionClasses(ModelEntity readEntity) {
    // TODO add entity.id check to throw an error Box if the wrong entity.property is used
    return """
    class ${readEntity.name}_ {
      ${_queryConditionBuilder(readEntity)}
    }""";
  }
}
