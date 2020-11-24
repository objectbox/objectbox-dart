import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'bindings/bindings.dart';
import 'bindings/helpers.dart';
import 'common.dart';
import 'modelinfo/index.dart';

class Model {
  final Pointer<OBX_model> _cModel;

  Pointer<OBX_model> get ptr => _cModel;

  Model(ModelInfo model)
      : _cModel = checkObxPtr(bindings.obx_model(), 'failed to create model') {
    try {
      model.entities.forEach(addEntity);

      // set last entity id
      bindings.obx_model_last_entity_id(
          _cModel, model.lastEntityId.id, model.lastEntityId.uid);
    } catch (e) {
      bindings.obx_model_free(_cModel);
      rethrow;
    }
  }

  void _check(int errorCode) {
    if (errorCode == OBX_SUCCESS) return;

    throw ObjectBoxException(
        dartMsg: 'Model building failed',
        nativeCode: bindings.obx_model_error_code(_cModel),
        nativeMsg: cString(bindings.obx_model_error_message(_cModel)));
  }

  void addEntity(ModelEntity entity) {
    // start entity
    var name = Utf8.toUtf8(entity.name).cast<Int8>();
    try {
      _check(bindings.obx_model_entity(
          _cModel, name, entity.id.id, entity.id.uid));
    } finally {
      free(name);
    }

    if (entity.flags != 0) {
      // TODO remove try-catch after upgrading to objectbox-c v0.11 where obx_model_entity_flags() exists.
      try {
        _check(bindings.obx_model_entity_flags(_cModel, entity.flags));
      } on ArgumentError {
        // flags not supported; don't do anything until objectbox-c v0.11
        // this should only be used from our test code
      }
    }

    // add all properties
    entity.properties.forEach(addProperty);

    // set last property id
    _check(bindings.obx_model_entity_last_property_id(
        _cModel, entity.lastPropertyId.id, entity.lastPropertyId.uid));
  }

  void addProperty(ModelProperty prop) {
    var name = Utf8.toUtf8(prop.name).cast<Int8>();
    try {
      _check(bindings.obx_model_property(
          _cModel, name, prop.type, prop.id.id, prop.id.uid));
    } finally {
      free(name);
    }

    if (prop.flags != 0) {
      _check(bindings.obx_model_property_flags(_cModel, prop.flags));
    }
  }
}
