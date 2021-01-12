import '../relations/to_one.dart';
import '../store.dart';
import 'modelentity.dart';

typedef ObjectReader<T> = Map<String, dynamic> Function(T object);
typedef ObjectWriter<T> = T Function(
    Store store, Map<String, dynamic> properties);
typedef ObjectGetId<T> = int /*?*/ Function(T object);
typedef ObjectSetId<T> = void Function(T object, int id);
typedef ObjectToOneRelations<T> = List<ToOne> Function(T object);

/// Used by the generated code as a container for model loading callables
class EntityDefinition<T> {
  final ModelEntity model;
  final ObjectReader<T> reader;
  final ObjectWriter<T> writer;
  final ObjectGetId<T> getId;
  final ObjectSetId<T> setId;
  final ObjectToOneRelations<T> toOneRelations;

  const EntityDefinition(
      {/*required*/ this.model,
      /*required*/ this.reader,
      /*required*/ this.writer,
      /*required*/ this.getId,
      /*required*/ this.setId,
      /*required*/ this.toOneRelations});

  Type type() {
    return T;
  }
}
