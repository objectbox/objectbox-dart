// Used by the generated code as a container for model loading callables
import 'package:objectbox/src/modelinfo/modelentity.dart';

typedef ObjectReader<T> = Map<String, dynamic> Function(T object);
typedef ObjectWriter<T> = T Function(Map<String, dynamic> properties);

class EntityDefinition<T> {
  final ModelEntity Function() getModel;
  final ObjectReader<T> reader;
  final ObjectWriter<T> writer;

  const EntityDefinition(this.getModel, this.reader, this.writer);

  Type type() {
    return T;
  }
}
