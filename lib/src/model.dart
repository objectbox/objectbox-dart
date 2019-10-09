import "dart:ffi";

import "bindings/bindings.dart";
import "bindings/helpers.dart";
import "modelinfo/index.dart";

import "package:ffi/ffi.dart";

class Model {
  Pointer<Void> _cModel;

  Model(List<ModelEntity> modelEntities) {
    _cModel = bindings.obx_model();
    checkObxPtr(_cModel, "failed to create model");

    try {
      // transform classes into model descriptions and loop through them
      modelEntities.forEach((currentEntity) {
        // start entity
        var entityUtf8 = Utf8.toUtf8(currentEntity.name);
        try {
          var entityNamePointer = entityUtf8.cast<Uint8>();
          checkObx(
              bindings.obx_model_entity(_cModel, entityNamePointer, currentEntity.id.id, currentEntity.id.uid));
        } finally {
          entityUtf8.free();
        }

        // add all properties
        currentEntity.properties.forEach((p) {
          var propertyUtf8 = Utf8.toUtf8(p.name);
          try {
            var propertyNamePointer = propertyUtf8.cast<Uint8>();
            checkObx(bindings.obx_model_property(_cModel, propertyNamePointer, p.type, p.id.id, p.id.uid));
            checkObx(bindings.obx_model_property_flags(_cModel, p.flags));
          } finally {
            propertyUtf8.free();
          }
        });

        // set last property id
        if (currentEntity.properties.isNotEmpty) {
          ModelProperty lastProp = currentEntity.properties[currentEntity.properties.length - 1];
          checkObx(bindings.obx_model_entity_last_property_id(_cModel, lastProp.id.id, lastProp.id.uid));
        }
      });

      // set last entity id
      if (modelEntities.isNotEmpty) {
        ModelEntity lastEntity = modelEntities[modelEntities.length - 1];
        bindings.obx_model_last_entity_id(_cModel, lastEntity.id.id, lastEntity.id.uid);
      }
    } catch (e) {
      bindings.obx_model_free(_cModel);
      _cModel = null;
      rethrow;
    }
  }

  get ptr => _cModel;
}
