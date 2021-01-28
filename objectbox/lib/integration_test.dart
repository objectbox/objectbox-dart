library integration_test;

import 'package:objectbox/internal.dart';
import './src/bindings/helpers.dart';
import './src/bindings/bindings.dart';

// Todo: maybe make this a standalone package

/// Implements simple integration tests for platform compatibility.
/// It's functions are designed to be callable from flutter apps - to test on the target platform.
class IntegrationTest {
  static const int64_max = 9223372036854775807;

  static void int64() {
    assert('9223372036854775807' == '$int64_max');
  }

  static void model() {
    // create a model with a single entity and a single property
    final modelInfo = ModelInfo();
    final property =
        ModelProperty(IdUid(1, int64_max - 1), 'id', OBXPropertyType.Long);
    final entity = ModelEntity(IdUid(1, int64_max), 'entity', modelInfo);
    property.entity = entity;
    entity.properties.add(property);
    entity.lastPropertyId = property.id;
    modelInfo.entities.add(entity);
    modelInfo.lastEntityId = entity.id;
    modelInfo.validate();

    final model = Model(modelInfo);
    checkObx(C.model_free(model.ptr));
  }
}
