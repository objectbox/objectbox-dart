import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart';
import 'package:flat_buffers/flex_buffers.dart' as flex;

/// Serializes any FlexBuffer-compatible value to bytes.
///
/// Supported types: bool, int, double, String, `List<dynamic>`,
/// `Map<String, dynamic>`, and nested combinations of these. List elements and
/// map values (not keys) can be null.
@pragma('vm:prefer-inline')
Uint8List toFlexBuffer(Object value) {
  final buffer = flex.Builder.buildFromObject(value);
  return buffer.asUint8List();
}

/// Reads the given field as a FlexBuffer and converts it to any Dart value.
///
/// Returns null if no data is stored for this field. The returned value can be
/// null, bool, int, double, String, `List<dynamic>`, `Map<String, dynamic>`,
/// or nested combinations of these.
///
/// If [skipNullCollectionValues], if a vector element is null or a map value is
/// null the list element or map entry is not returned. This can be used to
/// allow casting the return value of this method to [List] with non-null
/// elements (like `List<Object>`) and [Map] with non-null values (like
/// `Map<String, Object>`).
@pragma('vm:prefer-inline')
dynamic fromFlexBuffer(BufferContext buffer, int offset, int field,
    {bool skipNullCollectionValues = false}) {
  // Note: Uint8ListReader returns a Uint8List? cast to List<int>, so just cast
  // it back (if that ever changes, add a custom reader)
  final bytes = const Uint8ListReader(lazy: false)
      .vTableGetNullable(buffer, offset, field) as Uint8List?;
  if (bytes == null) return null;
  final ref = flex.Reference.fromBuffer(bytes.buffer);
  return _convertReference(ref, skipNullCollectionValues);
}

/// Deserializes FlexBuffer bytes to a `Map<String, dynamic>`.
@pragma('vm:prefer-inline')
Map<String, dynamic>? flexBufferToMap(
        BufferContext buffer, int offset, int field, {bool skipNull = false}) =>
    fromFlexBuffer(buffer, offset, field, skipNullCollectionValues: skipNull)
        as Map<String, dynamic>?;

/// Deserializes FlexBuffer bytes to a `List<dynamic>`.
@pragma('vm:prefer-inline')
List<dynamic>? flexBufferToList(BufferContext buffer, int offset, int field,
        {bool skipNull = false}) =>
    fromFlexBuffer(buffer, offset, field, skipNullCollectionValues: skipNull)
        as List<dynamic>?;

/// Deserializes FlexBuffer bytes to a `List<Map<String, dynamic>>`.
@pragma('vm:prefer-inline')
List<Map<String, dynamic>>? flexBufferToListOfMaps(
        BufferContext buffer, int offset, int field) =>
    flexBufferToList(buffer, offset, field, skipNull: true)
        ?.cast<Map<String, dynamic>>();

/// Recursively converts a FlexBuffer Reference to a Dart object.
///
/// For [skipNullCollectionValues] see [fromFlexBuffer].
dynamic _convertReference(flex.Reference ref, bool skipNullCollectionValues) {
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
      final value =
          _convertReference(valueIterator.current, skipNullCollectionValues);
      if (value != null || !skipNullCollectionValues) {
        map[keyIterator.current] = value;
      }
    }
    return map;
  } else if (ref.isVector) {
    final list = <dynamic>[];
    for (final element in ref.vectorIterable) {
      final value = _convertReference(element, skipNullCollectionValues);
      if (value != null || !skipNullCollectionValues) {
        list.add(value);
      }
    }
    return list;
  }

  throw UnsupportedError('Unsupported FlexBuffer value type');
}
