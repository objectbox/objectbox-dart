import 'dart:typed_data';

import '../flatbuffers/flat_buffers.dart';

/// Implements eager FlatBuffers list reader (default [ListReader] is lazy).
class EagerListReader<E> extends Reader<List<E>> {
  final Reader<E> _elementReader;

  /// Create a reader with the given element reader
  const EagerListReader(this._elementReader);

  /// offset size (uint32), see [ListReader]
  @override
  int get size => 4;

  @override
  List<E> read(BufferContext bc, int offset) {
    final listOffset = bc.derefObject(offset);
    final length = bc.buffer.getUint32(listOffset, Endian.little);
    return List<E>.generate(
        length,
        (int index) => _elementReader.read(
            bc, listOffset + size + _elementReader.size * index),
        growable: true);
  }
}
