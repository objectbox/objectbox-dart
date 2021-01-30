import 'dart:typed_data';

import '../../flatbuffers/flat_buffers.dart' as fb;
import '../relations/info.dart';
import '../relations/to_many.dart';
import '../relations/to_one.dart';
import '../store.dart';
import 'modelentity.dart';

// ignore_for_file: public_member_api_docs

/// Used by the generated code as a container for model loading callables
/// TODO change to an abstract class?
class EntityDefinition<T> {
  final ModelEntity model;
  final int Function(T, fb.Builder) objectToFB;
  final T Function(Store, Uint8List) objectFromFB;
  final int /*?*/ Function(T) getId;
  final void Function(T, int) setId;
  final List<ToOne> Function(T) toOneRelations;
  final Map<RelInfo, ToMany> Function(T) toManyRelations;

  const EntityDefinition(
      {/*required*/ this.model,
      /*required*/ this.objectToFB,
      /*required*/ this.objectFromFB,
      /*required*/ this.getId,
      /*required*/ this.setId,
      /*required*/ this.toOneRelations,
      /*required*/ this.toManyRelations});

  Type type() => T;
}
