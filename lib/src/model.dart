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

enum Type {
    Bool,
    Byte,
    Short,
    Char,
    Int,
    Long,
    Float,
    Double,
    String,
    Date,
    Relation,
    ByteVector,
    StringVector,
}

class Property {
    final Type type;
    final int id, uid;
    const Property({this.id, this.uid, this.type = null});
}

class Id {
    final Type type;
    final int id, uid;
    const Id({this.id, this.uid, this.type = null});
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
            return;         // current declaration is not a member variable (i.e. a constructor, function etc. instead)
        if(v.metadata.length != 1)
            return;         // too much or no metadata given

        var annotation = v.metadata[0].reflectee;
        var annotationType = annotation.runtimeType.toString();
        var flags = 0;
        if(annotationType == "Id")              // TODO: check that there is exactly one ID property
            flags |= OBXPropertyFlags.ID;
        else if(annotationType != "Property")
            return;         // invalid annotation
        
        var propertyTypeObx;
        if(annotation.type == null) {
            var propertyType = refl.instanceMembers[k].returnType.reflectedType.toString();
            if(propertyType == "int") propertyTypeObx = OBXPropertyType.Int;        // TODO: support more types
            else if(propertyType == "String") propertyTypeObx = OBXPropertyType.String;
        } else {
            switch(annotation.type) {
                case Type.Bool: propertyTypeObx = OBXPropertyType.Bool; break;
                case Type.Byte: propertyTypeObx = OBXPropertyType.Byte; break;
                case Type.Short: propertyTypeObx = OBXPropertyType.Short; break;
                case Type.Char: propertyTypeObx = OBXPropertyType.Char; break;
                case Type.Int: propertyTypeObx = OBXPropertyType.Int; break;
                case Type.Long: propertyTypeObx = OBXPropertyType.Long; break;
                case Type.Float: propertyTypeObx = OBXPropertyType.Float; break;
                case Type.Double: propertyTypeObx = OBXPropertyType.Double; break;
                case Type.String: propertyTypeObx = OBXPropertyType.String; break;
                case Type.Date: propertyTypeObx = OBXPropertyType.Date; break;
                case Type.Relation: propertyTypeObx = OBXPropertyType.Relation; break;
                case Type.ByteVector: propertyTypeObx = OBXPropertyType.ByteVector; break;
                case Type.StringVector: propertyTypeObx = OBXPropertyType.StringVector; break;
            }
        }
        check(propertyTypeObx != null);

        var symbolName = getSymbolName(k);
        var meta = v.metadata[0].reflectee;
        properties.add({
            "name": symbolName,
            "type": propertyTypeObx,
            "id": meta.id,                  // TODO: check that id is unique in this entity
            "uid": meta.uid,                // TODO: check that uid is globally unique
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
    get desc => _modelDescriptions;
}
