import "dart:ffi";
import "package:ffi/ffi.dart";

import 'bindings/constants.dart';
import "bindings/bindings.dart";
import "bindings/helpers.dart";
import 'common.dart';
import "modelinfo/index.dart";

class Model {
  Pointer<Void> _cModel;

  get ptr => _cModel;

  Model(List<ModelEntity> modelEntities) {
    _cModel = checkObxPtr(bindings.obx_model(), "failed to create model");

    try {
      // transform classes into model descriptions and loop through them
      modelEntities.forEach(addEntity);

      // set last entity id
      // TODO read last entity ID from the model
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

  void _check(int errorCode) {
    if (errorCode == OBXError.OBX_SUCCESS) return;

    int code = bindings.obx_model_error_code(_cModel);
    String text = cString(bindings.obx_model_error_message(_cModel));

    throw ObjectBoxException("$code $text");
  }

  void addEntity(ModelEntity entity) {
    // start entity
    var name = Utf8.toUtf8(entity.name);
    try {
      _check(bindings.obx_model_entity(_cModel, name.cast<Uint8>(), entity.id.id, entity.id.uid));
    } finally {
      free(name);
    }

    // add all properties
    entity.properties.forEach(addProperty);

    // set last property id
    _check(bindings.obx_model_entity_last_property_id(_cModel, entity.lastPropertyId.id, entity.lastPropertyId.uid));
  }

  void addProperty(ModelProperty prop) {
    var name = Utf8.toUtf8(prop.name);
    try {
      _check(bindings.obx_model_property(_cModel, name.cast<Uint8>(), prop.type, prop.id.id, prop.id.uid));
    } finally {
      free(name);
    }

    if (prop.flags != 0) {
      _check(bindings.obx_model_property_flags(_cModel, prop.flags));
    }
  }
}
