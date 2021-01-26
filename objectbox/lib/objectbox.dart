/// ObjectBox for Dart is a standalone database storing Dart objects locally,
/// with strong ACID semantics.
///
/// See the [README](https://github.com/objectbox/objectbox-dart#readme)
/// to get started.
library objectbox;

export 'src/annotations.dart';
export 'src/box.dart';
export 'src/common.dart';
export 'src/model.dart';
export 'src/modelinfo/index.dart';
export 'src/query/query.dart';
export 'src/relations/info.dart';
export 'src/relations/to_one.dart' hide InternalToOneAccess;
export 'src/relations/to_many.dart'
    hide InternalToManyAccess, InternalToManyTestAccess;
export 'src/store.dart' hide InternalStoreAccess;
export 'src/sync.dart';
export 'src/transaction.dart' show TxMode;
