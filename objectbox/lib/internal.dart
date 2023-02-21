/// This library serves as an entrypoint for generated code and objectbox tools.
/// Don't import into your own code, use 'objectbox.dart' instead.
library objectbox_internal;

// ignore_for_file: invalid_export_of_internal_element

export 'src/model.dart';
export 'src/modelinfo/index.dart';
export 'src/query.dart'
// don't export the same things as objectbox.dart to avoid docs conflicts
    hide
        Query,
        QueryBuilder,
        Order,
        Condition,
        PropertyQuery,
        IntegerPropertyQuery,
        DoublePropertyQuery,
        StringPropertyQuery;
export 'src/relations/info.dart';
export 'src/relations/to_many.dart'
    show InternalToManyAccess, InternalToManyTestAccess;
export 'src/sync.dart' show InternalSyncTestAccess;
