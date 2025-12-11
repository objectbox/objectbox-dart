import 'dart:typed_data';

import 'package:flat_buffers/flex_buffers.dart' as flex;

// ignore_for_file: public_member_api_docs

/// Serializes a `Map<String, dynamic>` to FlexBuffer bytes.
///
/// Returns null if the input map is null.
@pragma('vm:prefer-inline')
Uint8List? mapToFlexBuffer(Map<String, dynamic>? map) {
  if (map == null) return null;
  final buffer = flex.Builder.buildFromObject(map);
  return buffer.asUint8List();
}

/// Serializes a `List<dynamic>` to FlexBuffer bytes.
///
/// Returns null if the input list is null.
@pragma('vm:prefer-inline')
Uint8List? listToFlexBuffer(List<dynamic>? list) {
  if (list == null) return null;
  final buffer = flex.Builder.buildFromObject(list);
  return buffer.asUint8List();
}

/// Deserializes FlexBuffer bytes to a `Map<String, dynamic>`.
///
/// Returns null if the input bytes are null.
@pragma('vm:prefer-inline')
Map<String, dynamic>? flexBufferToMap(Uint8List? bytes) {
  if (bytes == null) return null;
  final ref = flex.Reference.fromBuffer(bytes.buffer);
  return _convertReference(ref) as Map<String, dynamic>?;
}

/// Deserializes FlexBuffer bytes to a `List<dynamic>`.
///
/// Returns null if the input bytes are null.
@pragma('vm:prefer-inline')
List<dynamic>? flexBufferToList(Uint8List? bytes) {
  if (bytes == null) return null;
  final ref = flex.Reference.fromBuffer(bytes.buffer);
  return _convertReference(ref) as List<dynamic>?;
}

/// Deserializes FlexBuffer bytes to a `List<Map<String, dynamic>>`.
///
/// Returns null if the input bytes are null.
@pragma('vm:prefer-inline')
List<Map<String, dynamic>>? flexBufferToListOfMaps(Uint8List? bytes) =>
    flexBufferToList(bytes)?.cast<Map<String, dynamic>>();

/// Recursively converts a FlexBuffer Reference to a Dart object.
dynamic _convertReference(flex.Reference ref) {
  if (ref.isNull) {
    return null;
  } else if (ref.isBool) {
    return ref.boolValue;
  } else if (ref.isInt) {
    return ref.intValue;
  } else if (ref.isDouble) {
    return ref.doubleValue;
  } else if (ref.isString) {
    return ref.stringValue;
  } else if (ref.isBlob) {
    return ref.blobValue;
  } else if (ref.isMap) {
    final map = <String, dynamic>{};
    final keys = ref.mapKeyIterable;
    final values = ref.mapValueIterable;
    final keyIterator = keys.iterator;
    final valueIterator = values.iterator;
    while (keyIterator.moveNext() && valueIterator.moveNext()) {
      map[keyIterator.current] = _convertReference(valueIterator.current);
    }
    return map;
  } else if (ref.isVector) {
    return ref.vectorIterable.map(_convertReference).toList();
  }
  // Fallback: try to get any numeric value
  final num = ref.numValue;
  if (num != null) return num;

  throw UnsupportedError('Unsupported FlexBuffer value type');
}
