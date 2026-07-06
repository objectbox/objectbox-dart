/// This library serves as an entrypoint for generated code and objectbox tools.
/// Don't import into your own code, use 'objectbox.dart' instead.
library;

// Note: OBXVectorDistanceType and OBXHnswFlags are now exported via
// modelinfo/index.dart (enums.dart) instead of the ffigen bindings, and
// InternalStoreAccess via the platform-conditional store facade, so that this
// library never pulls dart:ffi into a web build.
export 'src/modelinfo/index.dart';
export 'src/native/bindings/flatbuffers_readers.dart';
export 'src/native/bindings/flexbuffers.dart';
export 'src/relations/info.dart';
export 'src/relations/to_many.dart'
    show InternalToManyAccess, InternalToManyTestAccess;
export 'src/store.dart' show InternalStoreAccess;
