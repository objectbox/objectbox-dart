export 'native/transaction.dart' if (dart.library.html) 'web/transaction.dart';

/// Configure transaction mode. Used with [Store.runInTransaction()].
enum TxMode {
  /// Read only transaction - trying to execute a write operation results in an
  /// error. This is useful if you want to group many reads inside a single
  /// transaction, e.g. to improve performance or to get a consistent view of
  /// the data across multiple operations.
  read,

  /// Read/Write transaction. There can be only a single write transaction at
  /// any time - it holds a lock on the database. Compared to read transaction,
  /// read/write transactions have much higher "cost", because they need to
  /// write data to the disk at the end.
  write,
}
