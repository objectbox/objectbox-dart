import 'dart:typed_data';

import 'package:flat_buffers/flex_buffers.dart' as flex;

// ignore_for_file: public_member_api_docs

/// Serializes any FlexBuffer-compatible value to bytes.
///
/// Supported types: null, bool, int, double, String, `List<dynamic>`,
/// `Map<String, dynamic>`, and nested combinations of these.
///
/// Returns null if the input value is null.
@pragma('vm:prefer-inline')
Uint8List? toFlexBuffer(dynamic value) {
  if (value == null) return null;
  final buffer = flex.Builder.buildFromObject(value);
  return buffer.asUint8List();
}

/// Deserializes FlexBuffer bytes to any Dart value.
///
/// Returns null if the input bytes are null. The returned value can be
/// null, bool, int, double, String, `List<dynamic>`, `Map<String, dynamic>`,
/// or nested combinations of these.
@pragma('vm:prefer-inline')
dynamic fromFlexBuffer(Uint8List? bytes) {
  if (bytes == null) return null;
  final ref = flex.Reference.fromBuffer(bytes.buffer);
  return _convertReference(ref);
}

/// Deserializes FlexBuffer bytes to a `Map<String, dynamic>`.
@pragma('vm:prefer-inline')
Map<String, dynamic>? flexBufferToMap(Uint8List? bytes) =>
    fromFlexBuffer(bytes) as Map<String, dynamic>?;

/// Deserializes FlexBuffer bytes to a `List<dynamic>`.
@pragma('vm:prefer-inline')
List<dynamic>? flexBufferToList(Uint8List? bytes) =>
    fromFlexBuffer(bytes) as List<dynamic>?;

/// Deserializes FlexBuffer bytes to a `List<Map<String, dynamic>>`.
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
