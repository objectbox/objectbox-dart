import "bindings/bindings.dart";
import "bindings/constants.dart";
import "ffi/cstring.dart";
import "common.dart";

import "dart:mirrors";

class Entity {
    final int id, uid;
    const Entity({this.id, this.uid});
}

class Property {
    final int id, uid;
    const Property({this.id, this.uid});
}

class Id {
    final int id, uid;
    const Id({this.id, this.uid});
}

_check(cond) { if(!cond) throw AssertionError(); }
_checkObx(err) { if(err != OBXErrors.OBX_SUCCESS) throw ObjectBoxException(Common.lastErrorString(err)); }

_getClassModel(cls) {
    var refl = reflectClass(cls);
    var properties = [];
    getSymbolName(sym) => sym.toString().split('"')[1];

    if(refl.metadata.length != 1)
        return null;
    var entity = {
        "name": getSymbolName(refl.simpleName),
        "id": refl.metadata[0].reflectee.id,
        "uid": refl.metadata[0].reflectee.uid
    };

    refl.declarations.forEach((k, v) {
        if(v.runtimeType.toString() != "_LocalVariableMirror")
            return;
        if(v.metadata.length != 1)
            return;

        var annotationType = v.metadata[0].reflectee.runtimeType.toString();
        var flags = 0;
        if(annotationType == "Id")
            flags |= OBXPropertyFlags.ID;
        
        var propertyType = refl.instanceMembers[k].returnType.reflectedType.toString();
        var propertyTypeObx;
        if(propertyType == "int") propertyTypeObx = OBXPropertyType.Int;        // TODO: support more types
        else if(propertyType == "String") propertyTypeObx = OBXPropertyType.String;
        _check(propertyTypeObx != null);

        var symbolName = getSymbolName(k);
        var meta = v.metadata[0].reflectee;
        properties.add({
            "name": symbolName,
            "type": propertyTypeObx,
            "id": meta.id,
            "uid": meta.uid,
            "flags": flags,
        });
    });

    return { "entity": entity, "properties": properties };
}

class Model {
    static create(classes) {
        var model = bindings.obx_model_create();
        _check(model.address != 0);

        try {
            // transform classes into model descriptions and loop through them
            var classModels = classes.map(_getClassModel).where((m) => m != null).toList();
            classModels.forEach((m) {
                // start entity
                var entityName = CString(m["entity"]["name"]);
                _checkObx(bindings.obx_model_entity(model, entityName.ptr, m["entity"]["id"], m["entity"]["uid"]));
                entityName.free();

                // add all properties
                m["properties"].forEach((p) {
                    var propertyName = CString(p["name"]);
                    _checkObx(bindings.obx_model_property(model, propertyName.ptr, p["type"], p["id"], p["uid"]));
                    _checkObx(bindings.obx_model_property_flags(model, p["flags"]));
                    propertyName.free();
                });

                // set last property id
                if(m["properties"].length > 0) {
                    var lastProp = m["properties"][m["properties"].length - 1];
                    _checkObx(bindings.obx_model_entity_last_property_id(model, lastProp["id"], lastProp["uid"]));
                }
            });

            // set last entity id
            if(classModels.length > 0) {
                var lastEntity = classModels[classModels.length - 1]["entity"];
                bindings.obx_model_last_entity_id(model, lastEntity["id"], lastEntity["uid"]);
            }
        } catch(e) {
            bindings.obx_model_free(model);
            model.free();
            rethrow;
        }

        return model;
    }
}
