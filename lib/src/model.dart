import "dart:ffi";

import "bindings/bindings.dart";
import "bindings/helpers.dart";

import "package:ffi/ffi.dart";

class Entity {
  const Entity();
}

class Property {
  final int type;
  const Property({this.type = null});
}

class Id {
  const Id();
}

class Model {
  Pointer<Void> _objectboxModel;

  Model(List<Map<String, dynamic>> modelDefinitions) {
    _objectboxModel = bindings.obx_model();
    checkObxPtr(_objectboxModel, "failed to create model");

    try {
      // transform classes into model descriptions and loop through them
      modelDefinitions.forEach((m) {
        // start entity
        var entityUtf8 = Utf8.toUtf8(m["name"]);
        try {
          var entityNamePointer = entityUtf8.cast<Uint8>();
          final entityId = new IdUid(m["id"]);
          checkObx(bindings.obx_model_entity(_objectboxModel, entityNamePointer, entityId.id, entityId.uid));
        } finally {
          // same pointer
          entityUtf8.free();
        }

        // add all properties
        m["properties"].forEach((p) {
          var propertyUtf8 = Utf8.toUtf8(p["name"]);
          try {
            var propertyNamePointer = propertyUtf8.cast<Uint8>();
            final propertyId = new IdUid(p["id"]);
            checkObx(bindings.obx_model_property(
                _objectboxModel, propertyNamePointer, p["type"], propertyId.id, propertyId.uid));
            checkObx(bindings.obx_model_property_flags(_objectboxModel, p["flags"]));
          } finally {
            propertyUtf8.free();
          }
        });

        // set last property id
        if (m["properties"].length > 0) {
          var lastProp = m["properties"][m["properties"].length - 1];
          final lastPropId = new IdUid(lastProp["id"]);
          checkObx(bindings.obx_model_entity_last_property_id(_objectboxModel, lastPropId.id, lastPropId.uid));
        }
      });

      // set last entity id
      if (modelDefinitions.length > 0) {
        var lastEntity = modelDefinitions[modelDefinitions.length - 1];
        final lastEntityId = new IdUid(lastEntity["id"]);
        bindings.obx_model_last_entity_id(_objectboxModel, lastEntityId.id, lastEntityId.uid);
      }
    } catch (e) {
      bindings.obx_model_free(_objectboxModel);
      _objectboxModel = null;
      rethrow;
    }
  }

  get ptr => _objectboxModel;
}
