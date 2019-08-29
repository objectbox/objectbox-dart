import "dart:ffi";
import "dart:mirrors";

import "bindings/bindings.dart";
import "bindings/constants.dart";
import "bindings/helpers.dart";
import "ffi/cstring.dart";

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
        check(propertyTypeObx != null);

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
    Pointer<Void> _objectboxModel;
    var _modelDescriptions;

    Model(classes) {
        _objectboxModel = bindings.obx_model_create();
        check(_objectboxModel.address != 0);

        try {
            // transform classes into model descriptions and loop through them
            _modelDescriptions = classes.map(_getClassModel).where((m) => m != null).toList();
            _modelDescriptions.forEach((m) {
                // start entity
                var entityName = CString(m["entity"]["name"]);
                checkObx(bindings.obx_model_entity(_objectboxModel, entityName.ptr, m["entity"]["id"], m["entity"]["uid"]));
                entityName.free();

                // add all properties
                m["properties"].forEach((p) {
                    var propertyName = CString(p["name"]);
                    checkObx(bindings.obx_model_property(_objectboxModel, propertyName.ptr, p["type"], p["id"], p["uid"]));
                    checkObx(bindings.obx_model_property_flags(_objectboxModel, p["flags"]));
                    propertyName.free();
                });

                // set last property id
                if(m["properties"].length > 0) {
                    var lastProp = m["properties"][m["properties"].length - 1];
                    checkObx(bindings.obx_model_entity_last_property_id(_objectboxModel, lastProp["id"], lastProp["uid"]));
                }
            });

            // set last entity id
            if(_modelDescriptions.length > 0) {
                var lastEntity = _modelDescriptions[_modelDescriptions.length - 1]["entity"];
                bindings.obx_model_last_entity_id(_objectboxModel, lastEntity["id"], lastEntity["uid"]);
            }
        } catch(e) {
            bindings.obx_model_free(_objectboxModel);
            _objectboxModel = null;
            rethrow;
        }
    }

    get ptr => _objectboxModel;
}
