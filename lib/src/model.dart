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

  Model(ModelInfo model) {
    _cModel = checkObxPtr(bindings.obx_model(), "failed to create model");

    try {
      model.entities.forEach(addEntity);

      // set last entity id
      bindings.obx_model_last_entity_id(_cModel, model.lastEntityId.id, model.lastEntityId.uid);
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

    throw ObjectBoxException(nativeCode: code, nativeMsg: text);
  }

  void addEntity(ModelEntity entity) {
    // start entity
    var name = Utf8.toUtf8(entity.name);
    try {
      _check(bindings.obx_model_entity(_cModel, name, entity.id.id, entity.id.uid));
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
      _check(bindings.obx_model_property(_cModel, name, prop.type, prop.id.id, prop.id.uid));
    } finally {
      free(name);
    }

    if (prop.flags != 0) {
      _check(bindings.obx_model_property_flags(_cModel, prop.flags));
    }
  }
}
