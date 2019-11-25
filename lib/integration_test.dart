library integration_test;

import 'package:objectbox/objectbox.dart';
import './src/bindings/constants.dart';
import './src/bindings/helpers.dart';
import './src/bindings/bindings.dart';

// Todo: maybe make this a standalone package

/// Implements simple integration tests for platform compatibility.
/// It's functions are designed to be callable from flutter apps - to test on the target platform.
class IntegrationTest {
  static const int64_max = 9223372036854775807;

  static int64() {
    assert("9223372036854775807" == "$int64_max");
  }

  static model() {
    // create a model with a single entity and a single property
    final modelInfo = ModelInfo.createDefault();
    final property = ModelProperty(IdUid(1, int64_max - 1), "id", OBXPropertyType.Long, 0, null);
    final entity = ModelEntity(IdUid(1, int64_max), null, "entity", [], modelInfo);
    property.entity = entity;
    entity.properties.add(property);
    entity.lastPropertyId = property.id;
    modelInfo.entities.add(entity);
    modelInfo.lastEntityId = entity.id;
    modelInfo.validate();

    final model = Model(modelInfo);
    checkObx(bindings.obx_model_free(model.ptr));
  }
}
