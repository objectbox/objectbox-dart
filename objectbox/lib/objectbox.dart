/// ObjectBox for Dart is a standalone database storing Dart objects locally,
/// with strong ACID semantics.
///
/// Read the [Getting Started](https://docs.objectbox.io/getting-started) guide.
library objectbox;

export 'src/admin.dart' show Admin;
export 'src/annotations.dart';
export 'src/box.dart' show Box, PutMode;
export 'src/common.dart';
export 'src/native/query/vector_search_results.dart';
export 'src/query.dart'
    show
        Query,
        QueryBuilder,
        Order,
        Condition,
        PropertyQuery,
        IntegerPropertyQuery,
        DoublePropertyQuery,
        StringPropertyQuery,
        QuerySetParam,
        QueryParamString,
        QueryParamBytes,
        QueryParamInt,
        QueryParamBool,
        QueryParamDouble,
        QueryProperty,
        QueryStringProperty,
        QueryByteVectorProperty,
        QueryIntegerProperty,
        QueryDateProperty,
        QueryDateNanoProperty,
        QueryIntegerVectorProperty,
        QueryDoubleProperty,
        QueryDoubleVectorProperty,
        QueryBooleanProperty,
        QueryStringVectorProperty,
        QueryRelationToOne,
        QueryRelationToMany,
        QueryBacklinkToMany,
        QueryHnswProperty;
export 'src/relations/to_many.dart' show ToMany;
export 'src/relations/to_one.dart' show ToOne;
export 'src/store.dart' show Store, ObservableStore;
export 'src/sync.dart'
    show
        Sync,
        SyncChange,
        SyncClient,
        SyncConnectionEvent,
        SyncCredentials,
        SyncRequestUpdatesMode,
        SyncState,
        SyncLoginEvent;
export 'src/transaction.dart' show TxMode;
