/// This library serves as an entrypoint for generated code and objectbox tools.
/// Don't import into your own code, use 'objectbox.dart' instead.
library objectbox_internal;

export 'src/modelinfo/index.dart';
export 'src/native/bindings/flatbuffers_readers.dart';
export 'src/native/bindings/objectbox_c.dart'
    show OBXVectorDistanceType, OBXHnswFlags;
export 'src/native/store.dart' show InternalStoreAccess;
export 'src/relations/info.dart';
export 'src/relations/to_many.dart'
    show InternalToManyAccess, InternalToManyTestAccess;
