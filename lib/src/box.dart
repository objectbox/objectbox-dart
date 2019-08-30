import "dart:ffi";
import "dart:mirrors";
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

class Box<T> {
    Store _store;
    Pointer<Void> _objectboxBox;
    var _entityDescription, _idPropIdx;

    Box(this._store) {
        _entityDescription = _store.getEntityDescriptionFromClass(T);
        check(_entityDescription != null);
        _idPropIdx = _entityDescription["properties"].indexWhere((p) => (p["flags"] & OBXPropertyFlags.ID) != 0);
        check(_idPropIdx != -1);

        _objectboxBox = bindings.obx_box(_store.ptr, _entityDescription["entity"]["id"]);
        check(_objectboxBox != null);
        check(_objectboxBox.address != 0);
    }

    _marshal(propVals) {
        var builder = new fb.Builder(initialSize: 1024);

        // write all strings
        propVals.forEach((p) {
            switch(p["type"]) {
                case OBXPropertyType.String: p["offset"] = builder.writeString(p["value"]); break;
            }
        });

        // create table and write actual properties
        builder.startTable();
        propVals.forEach((p) {
            var id = p["id"] - 1, value = p["value"];
            switch(p["type"]) {
                case OBXPropertyType.Bool: builder.addBool(id, value); break;
                case OBXPropertyType.Char: builder.addUint8(id, value); break;
                case OBXPropertyType.Byte: builder.addInt8(id, value); break;
                case OBXPropertyType.Short: builder.addInt16(id, value); break;
                case OBXPropertyType.Int: builder.addInt32(id, value); break;
                case OBXPropertyType.Long: builder.addInt64(id, value); break;
                case OBXPropertyType.String: builder.addOffset(id, p["offset"]); break;
                // TODO: support more types
            }
        });

        var endOffset = builder.endTable();
        return builder.finish(endOffset);
    }

    put(T inst, {PutMode mode = PutMode.Put}) {         // also assigns a value to the respective ID property if it is given as null or 0
        var instRefl = reflect(inst);
        var propVals = _entityDescription["properties"].map((p) => {...p, "value": instRefl.getField(Symbol(p["name"])).reflectee }).toList();
        if(propVals[_idPropIdx]["value"] == null || propVals[_idPropIdx]["value"] == 0) {
            final id = bindings.obx_box_id_for_put(_objectboxBox, 0);
            propVals[_idPropIdx]["value"] = id;
            instRefl.setField(Symbol(propVals[_idPropIdx]["name"]), id);
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
        Pointer<Uint8> bufferPtr = allocate(count: ((buffer.length + 3.0) / 4.0).toInt() * 4);
        for(int i = 0; i < buffer.length; ++i)
            bufferPtr.elementAt(i).store(buffer[i] as int);

        // put object into box and free the buffer
        checkObx(bindings.obx_box_put(_objectboxBox, propVals[_idPropIdx]["value"], fromAddress(bufferPtr.address), buffer.length, putMode));
        bufferPtr.free();
    }

    close() {
        if(_store != null) {
            _store.close();
            _store = null;
        }
    }

    get ptr => _objectboxBox;
}
