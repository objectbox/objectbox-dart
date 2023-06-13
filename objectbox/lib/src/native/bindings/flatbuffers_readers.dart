import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart';

const int _sizeOfInt32 = 4;

/// A generic FlatBuffers list reader where `T` is a Dart `List<num>`.
abstract class _NumListReader<T extends List<num>> extends Reader<T> {
  const _NumListReader();

  @override
  @pragma('vm:prefer-inline')
  int get size => _sizeOfInt32;

  @override
  @pragma('vm:prefer-inline')
  T read(BufferContext bc, int offset) {
    final listOffset = bc.derefObject(offset);

    final length = bc.buffer.getUint32(listOffset, Endian.little);
    final result = createList(length);
    var baseOffset = listOffset + _sizeOfInt32 /* size of length value */;
    for (var i = 0; i < length; i++) {
      result[i] = getNumValue(bc.buffer, baseOffset + valueLength * i);
    }
    return result;
  }

  T createList(int length);

  /// The length of a number value in bytes.
  int get valueLength;

  num getNumValue(ByteData byteData, int byteOffset);
}

/// Reads a list of signed 16-bit integers as a [Int16List].
class Int16ListReader extends _NumListReader<Int16List> {
  /// See [Int16ListReader].
  const Int16ListReader();

  @override
  Int16List createList(int length) => Int16List(length);

  @override
  int get valueLength => Int16List.bytesPerElement;

  @override
  int getNumValue(ByteData byteData, int byteOffset) =>
      byteData.getInt16(byteOffset, Endian.little);
}

/// Reads a list of unsigned 16-bit integers as a [Uint16List].
///
/// The Uint16ListReader from FlatBuffers does not use a [Uint16List].
class Uint16ListReader extends _NumListReader<Uint16List> {
  /// See [Uint16ListReader].
  const Uint16ListReader();

  @override
  Uint16List createList(int length) => Uint16List(length);

  @override
  int get valueLength => Uint16List.bytesPerElement;

  @override
  int getNumValue(ByteData byteData, int byteOffset) =>
      byteData.getUint16(byteOffset, Endian.little);
}

/// Reads a list of signed 32-bit integers as a [Int32List].
class Int32ListReader extends _NumListReader<Int32List> {
  /// See [Int32ListReader].
  const Int32ListReader();

  @override
  Int32List createList(int length) => Int32List(length);

  @override
  int get valueLength => Int32List.bytesPerElement;

  @override
  int getNumValue(ByteData byteData, int byteOffset) =>
      byteData.getInt32(byteOffset, Endian.little);
}

/// Reads a list of unsigned 32-bit integers as a [Uint32List].
///
/// The Uint32ListReader from FlatBuffers does not use a [Uint32List].
class Uint32ListReader extends _NumListReader<Uint32List> {
  /// See [Uint32ListReader].
  const Uint32ListReader();

  @override
  Uint32List createList(int length) => Uint32List(length);

  @override
  int get valueLength => Uint32List.bytesPerElement;

  @override
  int getNumValue(ByteData byteData, int byteOffset) =>
      byteData.getUint32(byteOffset, Endian.little);
}

/// Reads a list of signed 64-bit integers as a [Int64List].
class Int64ListReader extends _NumListReader<Int64List> {
  /// See [Int64ListReader].
  const Int64ListReader();

  @override
  Int64List createList(int length) => Int64List(length);

  @override
  int get valueLength => Int64List.bytesPerElement;

  @override
  int getNumValue(ByteData byteData, int byteOffset) =>
      byteData.getInt64(byteOffset, Endian.little);
}

/// Reads a list of unsigned 64-bit integers as a [Uint64List].
class Uint64ListReader extends _NumListReader<Uint64List> {
  /// See [Uint64ListReader].
  const Uint64ListReader();

  @override
  Uint64List createList(int length) => Uint64List(length);

  @override
  int get valueLength => Uint64List.bytesPerElement;

  @override
  int getNumValue(ByteData byteData, int byteOffset) =>
      byteData.getUint64(byteOffset, Endian.little);
}

/// Reads a list of 32-bit floating points as a [Float32List].
///
/// The Float32ListReader from FlatBuffers does not use a [Float32List].
class Float32ListReader extends _NumListReader<Float32List> {
  /// See [Float32ListReader].
  const Float32ListReader();

  @override
  Float32List createList(int length) => Float32List(length);

  @override
  int get valueLength => Float32List.bytesPerElement;

  @override
  double getNumValue(ByteData byteData, int byteOffset) =>
      byteData.getFloat32(byteOffset, Endian.little);
}

/// Reads a list of 64-bit floating points as a [Float64List].
///
/// The Float64ListReader from FlatBuffers does not use a [Float64List].
class Float64ListReader extends _NumListReader<Float64List> {
  /// See [Float64ListReader].
  const Float64ListReader();

  @override
  Float64List createList(int length) => Float64List(length);

  @override
  int get valueLength => Float64List.bytesPerElement;

  @override
  double getNumValue(ByteData byteData, int byteOffset) =>
      byteData.getFloat64(byteOffset, Endian.little);
}
