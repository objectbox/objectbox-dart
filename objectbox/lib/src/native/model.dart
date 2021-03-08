import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../common.dart';
import '../modelinfo/index.dart';
import 'bindings/bindings.dart';
import 'bindings/helpers.dart';

// ignore_for_file: public_member_api_docs

class Model {
  final Pointer<OBX_model> _cModel;

  Pointer<OBX_model> get ptr => _cModel;

  Model(ModelInfo model)
      : _cModel = checkObxPtr(C.model(), 'failed to create model') {
    try {
      model.entities.forEach(addEntity);

      // set last entity id
      C.model_last_entity_id(
          _cModel, model.lastEntityId.id, model.lastEntityId.uid);

      // set last relation id
      if (model.lastRelationId != null) {
        C.model_last_relation_id(
            _cModel, model.lastRelationId.id, model.lastRelationId.uid);
      }

      // set last index id
      if (model.lastIndexId != null) {
        C.model_last_index_id(
            _cModel, model.lastIndexId.id, model.lastIndexId.uid);
      }
    } catch (e) {
      C.model_free(_cModel);
      rethrow;
    }
  }

  void _check(int errorCode) {
    if (errorCode == OBX_SUCCESS) return;

    throw ObjectBoxException(
        dartMsg: 'Model building failed',
        nativeCode: C.model_error_code(_cModel),
        nativeMsg: cString(C.model_error_message(_cModel)));
  }

  void addEntity(ModelEntity entity) {
    // start entity
    var name = entity.name.toNativeUtf8();
    try {
      _check(C.model_entity(_cModel, name.cast(), entity.id.id, entity.id.uid));
    } finally {
      calloc.free(name);
    }

    if (entity.flags != 0) {
      // TODO remove try-catch after upgrading to objectbox-c v0.11 where obx_model_entity_flags() exists.
      try {
        _check(C.model_entity_flags(_cModel, entity.flags));
      } on ArgumentError {
        // flags not supported; don't do anything until objectbox-c v0.11
        // this should only be used from our test code
      }
    }

    // add all properties
    entity.properties.forEach(addProperty);

    // set last property id
    _check(C.model_entity_last_property_id(
        _cModel, entity.lastPropertyId.id, entity.lastPropertyId.uid));

    entity.relations.forEach(addRelation);
  }

  void addProperty(ModelProperty prop) {
    var name = prop.name.toNativeUtf8();
    try {
      _check(C.model_property(
          _cModel, name.cast(), prop.type, prop.id.id, prop.id.uid));

      if (prop.isRelation) {
        var relTarget = prop.relationTarget! .toNativeUtf8();
        try {
          _check(C.model_property_relation(_cModel, relTarget.cast(),
              prop.indexId! .id, prop.indexId! .uid));
        } finally {
          calloc.free(relTarget);
        }
      } else if (prop.indexId != null) {
        _check(C.model_property_index_id(
            _cModel, prop.indexId!.id, prop.indexId!.uid));
      }
    } finally {
      calloc.free(name);
    }

    if (prop.flags != 0) {
      _check(C.model_property_flags(_cModel, prop.flags));
    }
  }

  void addRelation(ModelRelation rel) {
    _check(C.model_relation(
        _cModel, rel.id.id, rel.id.uid, rel.targetId.id, rel.targetId.uid));
  }
}
