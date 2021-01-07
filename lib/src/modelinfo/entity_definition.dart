import 'modelentity.dart';

typedef ObjectReader<T> = Map<String, dynamic> Function(T object);
typedef ObjectWriter<T> = T Function(Map<String, dynamic> properties);
typedef ObjectGetId<T> = int /*?*/ Function(T object);
typedef ObjectSetId<T> = void Function(T object, int id);

/// Used by the generated code as a container for model loading callables
class EntityDefinition<T> {
  final ModelEntity model;
  final ObjectReader<T> reader;
  final ObjectWriter<T> writer;
  final ObjectGetId<T> getId;
  final ObjectSetId<T> setId;

  const EntityDefinition(
      {/*required*/ this.model,
      /*required*/ this.reader,
      /*required*/ this.writer,
      /*required*/ this.getId,
      /*required*/ this.setId});

  Type type() {
    return T;
  }
}
