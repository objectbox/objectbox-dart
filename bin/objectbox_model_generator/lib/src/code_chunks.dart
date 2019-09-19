import "modelinfo/entity.dart";

class CodeChunks {
  static String modelInfoLoader(String allModelsJsonFilename) => """
      Map<String, Map<String, dynamic>> _allOBXModels = null;

      void _loadOBXModels() {
        if (FileSystemEntity.typeSync("$allModelsJsonFilename") == FileSystemEntityType.notFound)
          throw Exception("$allModelsJsonFilename not found");

        _allOBXModels = {};
        Map<String, dynamic> models = json.decode(new File("$allModelsJsonFilename").readAsStringSync());
        models["entities"].forEach((v) => _allOBXModels[v["name"]] = v);
      }

      Map<String, dynamic> _getOBXModel(String entityName) {
        if (_allOBXModels == null) _loadOBXModels();
        if (!_allOBXModels.containsKey(entityName)) throw Exception("entity missing in $allModelsJsonFilename: \$entityName");
        return _allOBXModels[entityName];
      }
    """;

  static String instanceBuildersReaders(Entity readEntity) {
    String name = readEntity.name;
    return """
        Map<String, dynamic> _${name}_OBXModelGetter() {
          return _getOBXModel("$name");
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

        const ${name}_OBXDefs = {
          "model": _${name}_OBXModelGetter,
          "builder": _${name}_OBXBuilder,
          "reader": _${name}_OBXReader,
        };
      """;
  }
}
