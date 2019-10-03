import "package:objectbox/src/modelinfo/index.dart";

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
}
