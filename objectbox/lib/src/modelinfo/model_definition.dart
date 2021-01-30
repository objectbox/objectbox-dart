// ignore_for_file: public_member_api_docs

import 'entity_definition.dart';
import 'modelinfo.dart';

class ModelDefinition {
  final ModelInfo model;
  final Map<Type, EntityDefinition> bindings;

  const ModelDefinition(this.model, this.bindings);
}
