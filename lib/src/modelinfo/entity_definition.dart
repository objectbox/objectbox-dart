import 'dart:typed_data';

import '../../flatbuffers/flat_buffers.dart' as fb;
import 'modelentity.dart';

/// Used by the generated code as a container for model loading callables
/// TODO change to an abstract class?
class EntityDefinition<T> {
  final ModelEntity model;
  final int Function(T, fb.Builder) objectToFB;
  final T Function(Uint8List) objectFromFB;
  final int /*?*/ Function(T) getId;
  final void Function(T, int) setId;

  const EntityDefinition(
      {/*required*/ this.model,
      /*required*/ this.objectToFB,
      /*required*/ this.objectFromFB,
      /*required*/ this.getId,
      /*required*/ this.setId});

  Type type() {
    return T;
  }
}
