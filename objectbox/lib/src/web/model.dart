// Web (stub) implementation of the model builder: mirrors the public API of
// `../native/model.dart` so the package compiles for the web platform, but
// throws `UnsupportedError` at runtime. See tracking issue #185.
// ignore_for_file: public_member_api_docs

import 'package:meta/meta.dart';

import '../modelinfo/index.dart';
import 'unsupported.dart';

@internal
class Model {
  Model(ModelInfo model) {
    throwUnsupportedOnWeb();
  }

  void addEntity(ModelEntity entity) => throwUnsupportedOnWeb();

  void addProperty(ModelProperty prop) => throwUnsupportedOnWeb();

  void addRelation(ModelRelation rel) => throwUnsupportedOnWeb();
}
