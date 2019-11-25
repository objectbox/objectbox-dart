import 'package:objectbox/src/modelinfo/modelentity.dart';

typedef ObjectReader<T> = Map<String, dynamic> Function(T object);
typedef ObjectWriter<T> = T Function(Map<String, dynamic> properties);

/// Used by the generated code as a container for model loading callables
class EntityDefinition<T> {
  final ModelEntity model;
  final ObjectReader<T> reader;
  final ObjectWriter<T> writer;

  const EntityDefinition({this.model, this.reader, this.writer});

  Type type() {
    return T;
  }
}
