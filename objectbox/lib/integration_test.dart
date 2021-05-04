library integration_test;

import './src/native/bindings/bindings.dart' as native;
import './src/native/bindings/helpers.dart' as native;
import 'internal.dart';

// ignore_for_file: public_member_api_docs

// Todo: maybe make this a standalone package

/// Implements simple integration tests for platform compatibility.
/// It's functions are designed to be callable from flutter apps - to test on the target platform.
class IntegrationTest {
  static const int64Max = 9223372036854775807;

  static void int64() {
    assert('9223372036854775807' == '$int64Max');
  }

  static void model() {
    // create a model with a single entity and a single property
    final modelInfo = ModelInfo.empty();
    final property = ModelProperty.create(
        const IdUid(1, int64Max - 1), 'id', OBXPropertyType.Long);
    final entity =
        ModelEntity.create(const IdUid(1, int64Max), 'entity', modelInfo);
    property.entity = entity;
    entity.properties.add(property);
    entity.lastPropertyId = property.id;
    modelInfo.entities.add(entity);
    modelInfo.lastEntityId = entity.id;
    modelInfo.validate();

    final model = Model(modelInfo);
    native.checkObx(native.C.model_free(model.ptr));
  }
}
