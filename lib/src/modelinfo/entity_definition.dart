import 'dart:typed_data';

import '../../flatbuffers/flat_buffers.dart' as fb;
import '../relations/to_one.dart';
import '../store.dart';
import 'modelentity.dart';

/// Used by the generated code as a container for model loading callables
/// TODO change to an abstract class?
class EntityDefinition<T> {
  final ModelEntity model;
  final int Function(T, fb.Builder) objectToFB;
  final T Function(Store, Uint8List) objectFromFB;
  final int /*?*/ Function(T) getId;
  final void Function(T, int) setId;
  final List<ToOne> Function(T) toOneRelations;

  const EntityDefinition(
      {/*required*/ this.model,
      /*required*/ this.objectToFB,
      /*required*/ this.objectFromFB,
      /*required*/ this.getId,
      /*required*/ this.setId,
      /*required*/ this.toOneRelations});

  Type type() {
    return T;
  }
}
