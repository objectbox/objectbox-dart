import "dart:ffi";
import "dart:typed_data" show Uint8List;
import "package:flat_buffers/flat_buffers.dart" as fb;

import "constants.dart";
import "structs.dart";
import "../modelinfo/index.dart";

class _OBXFBEntity {
  _OBXFBEntity._(this._bc, this._bcOffset);

  static const fb.Reader<_OBXFBEntity> reader = _OBXFBEntityReader();

  factory _OBXFBEntity(final Uint8List bytes) {
    fb.BufferContext rootRef = fb.BufferContext.fromBytes(bytes);
    return reader.read(rootRef, 0);
  }

  final fb.BufferContext _bc;
  final int _bcOffset;

  getProp(propReader, int field) => propReader.vTableGet(_bc, _bcOffset, field);
}

class _OBXFBEntityReader extends fb.TableReader<_OBXFBEntity> {
  const _OBXFBEntityReader();

  @override
  _OBXFBEntity createObject(fb.BufferContext bc, int offset) => _OBXFBEntity._(bc, offset);
}

class OBXFlatbuffersManager<T> {
  ModelEntity _modelEntity;
  ObjectWriter<T> _entityBuilder;

  OBXFlatbuffersManager(this._modelEntity, this._entityBuilder);

  Pointer<OBX_bytes> marshal(Map<String, dynamic> propVals) {
    var builder = fb.Builder(initialSize: 1024);

    // write all strings
    Map<String, int> offsets = {};
    _modelEntity.properties.forEach((p) {
      switch (p.type) {
        case OBXPropertyType.String:
          offsets[p.name] = builder.writeString(propVals[p.name]);
          break;
      }
    });

    // create table and write actual properties
    // TODO: make sure that Id property has a value >= 1
    builder.startTable();
    _modelEntity.properties.forEach((p) {
      var field = p.id.id - 1, value = propVals[p.name];
      switch (p.type) {
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
          builder.addOffset(field, offsets[p.name]);
          break;
        case OBXPropertyType.Float:
          builder.addFloat32(field, value);
          break;
        case OBXPropertyType.Double:
          builder.addFloat64(field, value);
          break;
        default:
          throw Exception("unsupported type: ${p.type}"); // TODO: support more types
      }
    });

    var endOffset = builder.endTable();
    return OBX_bytes.managedCopyOf(builder.finish(endOffset));
  }

  T unmarshal(final Uint8List bytes) {
    final entity = _OBXFBEntity(bytes);
    Map<String, dynamic> propVals = {};

    _modelEntity.properties.forEach((p) {
      var propReader;
      switch (p.type) {
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
        case OBXPropertyType.Float:
          propReader = fb.Float32Reader();
          break;
        case OBXPropertyType.Double:
          propReader = fb.Float64Reader();
          break;
        default:
          throw Exception("unsupported type: ${p.type}"); // TODO: support more types
      }

      propVals[p.name] = entity.getProp(propReader, (p.id.id + 1) * 2);
    });

    return _entityBuilder(propVals);
  }

  // expects pointer to OBX_bytes_array and manually resolves its contents (see objectbox.h)
  List<T> unmarshalArray(final Pointer<OBX_bytes_array> bytesArray, {bool allowMissing = false}) {
    final OBX_bytes_array array = bytesArray.ref;
    var fn = (OBX_bytes b) => unmarshal(b.data);
    if (allowMissing) {
      fn = (OBX_bytes b) => b.isEmpty ? null : unmarshal(b.data);
    }
    return array.items().map<T>(fn).toList();
  }
}
