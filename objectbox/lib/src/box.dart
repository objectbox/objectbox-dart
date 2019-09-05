import "dart:ffi";
import "dart:typed_data" show Uint8List;
import "package:flat_buffers/flat_buffers.dart" as fb;

import "store.dart";
import "bindings/bindings.dart";
import "bindings/constants.dart";
import "bindings/helpers.dart";

enum PutMode {
    Put,
    Insert,
    Update,
}

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
    _OBXFBEntity createObject(fb.BufferContext bc, int offset) =>
        new _OBXFBEntity._(bc, offset);
}

class Box<T> {
    Store _store;
    Pointer<Void> _objectboxBox;
    var _entityDefinition, _entityReader, _entityBuilder;

    Box(this._store) {
        _entityDefinition = _store.getEntityModelDefinitionFromClass(T);
        _entityReader = _store.getEntityReaderFromClass<T>();
        _entityBuilder = _store.getEntityBuilderFromClass<T>();

        _objectboxBox = bindings.obx_box(_store.ptr, _entityDefinition["entity"]["id"]);
        check(_objectboxBox != null);
        check(_objectboxBox.address != 0);
    }

    _marshal(propVals) {
        var builder = new fb.Builder(initialSize: 1024);

        // write all strings
        _entityDefinition["properties"].forEach((p) {
            switch(p["type"]) {
                case OBXPropertyType.String: p["offset"] = builder.writeString(propVals[p["name"]]); break;
            }
        });

        // create table and write actual properties
        // TODO: make sure that Id property has a value >= 1
        builder.startTable();
        _entityDefinition["properties"].forEach((p) {
            var field = p["flatbuffers_id"], value = propVals[p["name"]];
            switch(p["type"]) {
                case OBXPropertyType.Bool: builder.addBool(field, value); break;
                case OBXPropertyType.Char: builder.addInt8(field, value); break;
                case OBXPropertyType.Byte: builder.addUint8(field, value); break;
                case OBXPropertyType.Short: builder.addInt16(field, value); break;
                case OBXPropertyType.Int: builder.addInt32(field, value); break;
                case OBXPropertyType.Long: builder.addInt64(field, value); break;
                case OBXPropertyType.String: builder.addOffset(field, p["offset"]); break;
                default: throw Exception("unsupported type: ${p['type']}");         // TODO: support more types
            }
        });

        var endOffset = builder.endTable();
        return builder.finish(endOffset);
    }

    _unmarshal(buffer) {
        Map<String, dynamic> propVals = {};
        var entity = new _OBXFBEntity(buffer);

        _entityDefinition["properties"].forEach((p) {
            var propReader;
            switch(p["type"]) {
                case OBXPropertyType.Bool: propReader = fb.BoolReader(); break;
                case OBXPropertyType.Char: propReader = fb.Int8Reader(); break;
                case OBXPropertyType.Byte: propReader = fb.Uint8Reader(); break;
                case OBXPropertyType.Short: propReader = fb.Int16Reader(); break;
                case OBXPropertyType.Int: propReader = fb.Int32Reader(); break;
                case OBXPropertyType.Long: propReader = fb.Int64Reader(); break;
                case OBXPropertyType.String: propReader = fb.StringReader(); break;
                default: throw Exception("unsupported type: ${p['type']}");         // TODO: support more types
            }

            propVals[p["name"]] = entity.getProp(propReader, (p["flatbuffers_id"] + 2) * 2);
        });

        return _entityBuilder(propVals);
    }

    put(T inst, {PutMode mode = PutMode.Put}) {         // if the respective ID property is given as null or 0, a newly assigned ID is returned, otherwise the existing ID is returned
        var propVals = _entityReader(inst);
        var idPropName = _entityDefinition["idPropertyName"];
        if(propVals[idPropName] == null || propVals[idPropName] == 0) {
            final id = bindings.obx_box_id_for_put(_objectboxBox, 0);
            propVals[idPropName] = id;
        }
        var buffer = _marshal(propVals);
        
        // determine internal put mode from given enum
        var putMode;
        switch(mode) {
            case PutMode.Put: putMode = OBXPutMode.PUT; break;
            case PutMode.Insert: putMode = OBXPutMode.INSERT; break;
            case PutMode.Update: putMode = OBXPutMode.UPDATE; break;
        }

        // transform flatbuffers byte array into memory area for C, with a length of a multiple of four
        Pointer<Uint8> bufferPtr = Pointer.allocate(count: ((buffer.length + 3.0) / 4.0).toInt() * 4);
        for(int i = 0; i < buffer.length; ++i)
            bufferPtr.elementAt(i).store(buffer[i] as int);

        // put object into box and free the buffer
        checkObx(bindings.obx_box_put(_objectboxBox, propVals[idPropName], Pointer.fromAddress(bufferPtr.address), buffer.length, putMode));
        bufferPtr.free();
        return propVals[idPropName];
    }

    getById(int id) {
        Pointer<Pointer<Void>> dataPtr = Pointer.allocate();
        Pointer<Int32> sizePtr = Pointer.allocate();

        // get element with specified id from database
        Pointer<Void> txn = bindings.obx_txn_read(_store.ptr);
        check(txn != null && txn.address != 0);
        checkObx(bindings.obx_box_get(_objectboxBox, id, dataPtr, sizePtr));
        checkObx(bindings.obx_txn_close(txn));
        Pointer<Uint8> data = Pointer.fromAddress(dataPtr.load<Pointer<Void>>().address);
        var size = sizePtr.load<int>();

        // transform bytes from memory to Dart byte list
        var buffer = new Uint8List(size);
        for(int i = 0; i < size; ++i)           // TODO: move this to a separate class
            buffer[i] = data.elementAt(i).load<int>();
        dataPtr.free();
        sizePtr.free();

        return _unmarshal(buffer);
    }

    close() {
        if(_store != null) {
            _store.close();
            _store = null;
        }
    }

    get ptr => _objectboxBox;
}
