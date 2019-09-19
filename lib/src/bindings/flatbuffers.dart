import "dart:ffi";
import "dart:typed_data" show Uint8List;
import "package:flat_buffers/flat_buffers.dart" as fb;

import "constants.dart";
import "helpers.dart";
import "structs.dart";

class _OBXFBEntity {
  _OBXFBEntity._(this._bc, this._bcOffset);
  static const fb.Reader<_OBXFBEntity> reader = const _OBXFBEntityReader();
  factory _OBXFBEntity(Uint8List bytes) {
    fb.BufferContext rootRef = new fb.BufferContext.fromBytes(bytes);
    return reader.read(rootRef, 0);
  }

  final fb.BufferContext _bc;
  final int _bcOffset;

  getProp(propReader, int field) => propReader.vTableGet(_bc, _bcOffset, field);
}

class _OBXFBEntityReader extends fb.TableReader<_OBXFBEntity> {
  const _OBXFBEntityReader();

  @override
  _OBXFBEntity createObject(fb.BufferContext bc, int offset) => new _OBXFBEntity._(bc, offset);
}

class OBXFlatbuffersManager<T> {
  var _entityDefinition, _entityReader, _entityBuilder;

  OBXFlatbuffersManager(this._entityDefinition, this._entityReader, this._entityBuilder);

  ByteBuffer marshal(propVals) {
    var builder = new fb.Builder(initialSize: 1024);

    // write all strings
    Map<String, int> offsets = {};
    _entityDefinition["properties"].forEach((p) {
      switch (p["type"]) {
        case OBXPropertyType.String:
          offsets[p["name"]] = builder.writeString(propVals[p["name"]]);
          break;
      }
    });

    // create table and write actual properties
    // TODO: make sure that Id property has a value >= 1
    builder.startTable();
    _entityDefinition["properties"].forEach((p) {
      final int pId = new IdUid(p["id"]).id;
      var field = pId - 1, value = propVals[p["name"]];
      switch (p["type"]) {
        case OBXPropertyType.Bool:
          builder.addBool(field, value);
          break;
        case OBXPropertyType.Char:
          builder.addInt8(field, value);
          break;
        case OBXPropertyType.Byte:
          builder.addUint8(field, value);
          break;
        case OBXPropertyType.Short:
          builder.addInt16(field, value);
          break;
        case OBXPropertyType.Int:
          builder.addInt32(field, value);
          break;
        case OBXPropertyType.Long:
          builder.addInt64(field, value);
          break;
        case OBXPropertyType.String:
          builder.addOffset(field, offsets[p["name"]]);
          break;
        default:
          throw Exception("unsupported type: ${p['type']}"); // TODO: support more types
      }
    });

    var endOffset = builder.endTable();
    return ByteBuffer.allocate(builder.finish(endOffset));
  }

  T unmarshal(ByteBuffer buffer) {
    if (buffer.size == 0 || buffer.address == 0) return null;
    Map<String, dynamic> propVals = {};
    var entity = new _OBXFBEntity(buffer.data);

    _entityDefinition["properties"].forEach((p) {
      var propReader;
      switch (p["type"]) {
        case OBXPropertyType.Bool:
          propReader = fb.BoolReader();
          break;
        case OBXPropertyType.Char:
          propReader = fb.Int8Reader();
          break;
        case OBXPropertyType.Byte:
          propReader = fb.Uint8Reader();
          break;
        case OBXPropertyType.Short:
          propReader = fb.Int16Reader();
          break;
        case OBXPropertyType.Int:
          propReader = fb.Int32Reader();
          break;
        case OBXPropertyType.Long:
          propReader = fb.Int64Reader();
          break;
        case OBXPropertyType.String:
          propReader = fb.StringReader();
          break;
        default:
          throw Exception("unsupported type: ${p['type']}"); // TODO: support more types
      }

      final int pId = new IdUid(p["id"]).id;
      propVals[p["name"]] = entity.getProp(propReader, (pId + 1) * 2);
    });

    return _entityBuilder(propVals);
  }

  // expects pointer to OBX_bytes_array and manually resolves its contents (see objectbox.h)
  List<T> unmarshalArray(Pointer<Uint64> bytesArray) {
    return ByteBufferArray.fromOBXBytesArray(bytesArray).buffers.map<T>((b) => unmarshal(b)).toList();
  }
}
