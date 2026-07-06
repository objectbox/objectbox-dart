// Generic FlatBuffers property reader for the web implementation: reads a
// single property value out of a stored record without needing the generated
// objectFromFB (used for @Unique enforcement and ToOne backlinks; later also
// by the query engine).
//
// The generated serialization assigns property with model id N to table field
// slot N-1, i.e. vtable offset 2 * N + 2 (see generator/lib/src/code_chunks.dart).
// ignore_for_file: public_member_api_docs

import 'dart:typed_data';

import '../../flatbuffers.dart' as fb;

import '../modelinfo/enums.dart';
import '../modelinfo/modelproperty.dart';

int vTableOffset(ModelProperty property) => property.id.id * 2 + 2;

/// Reads the value of [property] from a serialized record.
///
/// Returns null for absent optional values. Scalars, strings and vectors are
/// supported; [OBXPropertyType.Flex] is not (returns null).
Object? readProperty(ModelProperty property, ByteData data) {
  final buffer = fb.BufferContext(data);
  final rootOffset = buffer.derefObject(0);
  final offset = vTableOffset(property);
  switch (property.type) {
    case OBXPropertyType.Bool:
      return const fb.BoolReader()
          .vTableGetNullable(buffer, rootOffset, offset);
    case OBXPropertyType.Byte:
    case OBXPropertyType.Short:
    case OBXPropertyType.Char:
    case OBXPropertyType.Int:
    case OBXPropertyType.Long:
    case OBXPropertyType.Date:
    case OBXPropertyType.DateNano:
    case OBXPropertyType.Relation:
      return const fb.Int64Reader()
          .vTableGetNullable(buffer, rootOffset, offset);
    case OBXPropertyType.Float:
      return const fb.Float32Reader()
          .vTableGetNullable(buffer, rootOffset, offset);
    case OBXPropertyType.Double:
      return const fb.Float64Reader()
          .vTableGetNullable(buffer, rootOffset, offset);
    case OBXPropertyType.String:
      return const fb.StringReader(asciiOptimization: true)
          .vTableGetNullable(buffer, rootOffset, offset);
    case OBXPropertyType.ByteVector:
      return const fb.Uint8ListReader()
          .vTableGetNullable(buffer, rootOffset, offset);
    case OBXPropertyType.StringVector:
      return const fb.ListReader<String>(fb.StringReader(), lazy: false)
          .vTableGetNullable(buffer, rootOffset, offset);
    case OBXPropertyType.FloatVector:
      return const fb.ListReader<double>(fb.Float32Reader(), lazy: false)
          .vTableGetNullable(buffer, rootOffset, offset);
    case OBXPropertyType.DoubleVector:
      return const fb.ListReader<double>(fb.Float64Reader(), lazy: false)
          .vTableGetNullable(buffer, rootOffset, offset);
    case OBXPropertyType.IntVector:
    case OBXPropertyType.LongVector:
    case OBXPropertyType.DateVector:
    case OBXPropertyType.DateNanoVector:
      return const fb.ListReader<int>(fb.Int64Reader(), lazy: false)
          .vTableGetNullable(buffer, rootOffset, offset);
    default:
      return null;
  }
}

/// Reads the int64 value of [property] (e.g. a ToOne target id), 0 if unset.
int readIntProperty(ModelProperty property, ByteData data) {
  final buffer = fb.BufferContext(data);
  final rootOffset = buffer.derefObject(0);
  return const fb.Int64Reader()
      .vTableGet(buffer, rootOffset, vTableOffset(property), 0);
}
