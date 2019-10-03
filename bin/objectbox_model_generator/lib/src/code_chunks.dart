import "package:objectbox/src/modelinfo/index.dart";
import "package:analyzer/dart/element/element.dart";
import "package:objectbox/src/bindings/constants.dart" show OBXPropertyType;
import "package:source_gen/source_gen.dart" show InvalidGenerationSourceError;

class CodeChunks {
  static String modelInfoLoader(String allModelsJsonFilename) => """
      Map<int, ModelEntity> _allOBXModelEntities = null;

      void _loadOBXModelEntities() {
      if (FileSystemEntity.typeSync("objectbox-model.json") == FileSystemEntityType.notFound)
          throw Exception("objectbox-model.json not found");

      _allOBXModelEntities = {};
      ModelInfo modelInfo = ModelInfo.fromMap(json.decode(new File("objectbox-model.json").readAsStringSync()));
      modelInfo.entities.forEach((e) => _allOBXModelEntities[e.id.uid] = e);
      }

      ModelEntity _getOBXModelEntity(int entityUid) {
      if (_allOBXModelEntities == null) _loadOBXModelEntities();
      if (!_allOBXModelEntities.containsKey(entityUid))
          throw Exception("entity uid missing in objectbox-model.json: \$entityUid");
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
          $name r = new $name();
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
      switch(f.type) {
        case OBXPropertyType.Bool:
          fieldType = "Boolean";
          break;
        case OBXPropertyType.String:
          fieldType = "String";
          break;
        case OBXPropertyType.Double:
          fieldType = "Double";
          break;
        integer:
        case OBXPropertyType.Int:
          fieldType = "Integer";
          break;
        case OBXPropertyType.Long:
          continue integer;
        default:
          throw InvalidGenerationSourceError("Unsupported property type (${f.type}): ${readEntity.name}.${name}");
      }

      ret.add("""
        static final ${name}PropertyId = ${f.id.id};
        static final ${name} = Query${fieldType}Property(entityId, ${name}PropertyId);
        """);
    }
    return ret.join();
  }

  static String queryConditionClasses(ModelEntity readEntity) {
    // TODO add entity.id check to throw an error Box if the wrong entity.property is used
    return """
    class ${readEntity.name}_ {
      static final entityId = ${readEntity.id.id};
      ${_queryConditionBuilder(readEntity)}
    }""";
  }
}
