import 'dart:ffi';
import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../relations/info.dart';
import '../relations/to_many.dart';
import '../relations/to_one.dart';
import '../store.dart';
import 'modelentity.dart';

// ignore_for_file: public_member_api_docs

/// Used by the generated code as a container for model loading callables
class EntityDefinition<T> {
  final ModelEntity model;
  final int Function(T, fb.Builder) objectToFB;
  final T Function(Store, ByteData) objectFromFB;
  final int? Function(T) getId;
  final void Function(T, int) setId;
  final List<ToOne> Function(T) toOneRelations;
  final Map<RelInfo, ToMany> Function(T) toManyRelations;

  const EntityDefinition(
      {required this.model,
      required this.objectToFB,
      required this.objectFromFB,
      required this.getId,
      required this.setId,
      required this.toOneRelations,
      required this.toManyRelations});

  Type type() => T;

  /// Shortcut that creates a [ByteData] view and passes it to [objectFromFB].
  T objectFromData(Store store, Pointer<Uint8> data, int size) {
    // There has been a performance improvement in the past using memcpy for
    // small buffers, but this is not longer faster than asTypedList.
    // See /benchmark/bin/native_pointers.dart.
    final uInt8List = data.asTypedList(size);
    final byteData =
        ByteData.view(uInt8List.buffer, uInt8List.offsetInBytes, size);
    return objectFromFB(store, byteData);
  }
}
