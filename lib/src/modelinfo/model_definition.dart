import 'package:objectbox/src/modelinfo/modelinfo.dart';
import 'package:objectbox/src/modelinfo/entity_definition.dart';

class ModelDefinition {
  final ModelInfo model;
  final Map<Type, EntityDefinition> bindings;

  const ModelDefinition(this.model, this.bindings);
}
