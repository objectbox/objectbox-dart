import '../objectbox.dart';

/// Wrapper for a semantic version information.
class Version {
  /// Major version number.
  final int major;

  /// Minor version number.
  final int minor;

  /// Patch version number.
  final int patch;

  /// Create a version identifier.
  const Version(this.major, this.minor, this.patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// ObjectBox database exception.
class ObjectBoxException implements Exception {
  /// Exception message.
  final String message;

  /// Create a new exception.
  ObjectBoxException(this.message);

  @override
  String toString() => 'ObjectBoxException: $message';
}

/// Thrown if a property query aggregate function (e.g. `sum()`) can not compute
/// a result due to a number type overflowing.
class NumericOverflowException extends ObjectBoxException {
  /// See [NumericOverflowException].
  NumericOverflowException(super.message);
}

/// ObjectBox database exception with an OBX_ERROR code.
class StorageException extends ObjectBoxException {
  /// OBX_ERROR code as defined in [objectbox.h of the C library](https://github.com/objectbox/objectbox-c/blob/main/include/objectbox.h).
  final int errorCode;

  /// Create with a message and OBX_ERROR code.
  StorageException(super.message, this.errorCode);

  @override
  String toString() => '$runtimeType: $message (OBX_ERROR code $errorCode)';
}

/// Thrown when applying a transaction (e.g. putting an object) would exceed the
/// `maxDBSizeInKB` configured when calling [Store.new].
class DbFullException extends StorageException {
  /// See [DbFullException].
  DbFullException(super.message, super.errorCode);
}

/// Thrown when applying a transaction would exceed the `maxDataSizeInKByte`
/// configured when calling [Store.new].
class DbMaxDataSizeExceededException extends StorageException {
  /// See [DbMaxDataSizeExceededException].
  DbMaxDataSizeExceededException(super.message, super.errorCode);
}

/// Thrown when the maximum amount of readers (read transactions) was exceeded.
///
/// Verify that your code only uses a reasonable amount of threads.
///
/// If a very high number of threads (>100) needs to be used, consider
/// setting `maxReaders` when calling [Store.new].
class DbMaxReadersExceededException extends StorageException {
  /// See [DbMaxReadersExceededException].
  DbMaxReadersExceededException(super.message, super.errorCode);
}

/// Thrown when an error occurred that requires the store to be closed.
///
/// This may be an I/O error. Regular operations won't be possible. To handle
/// this exit the app or try to reopen the store.
class DbShutdownException extends StorageException {
  /// See [DbShutdownException].
  DbShutdownException(super.message, super.errorCode);
}

/// A unique constraint would have been violated by this database operation.
class UniqueViolationException extends ObjectBoxException {
  /// Create a new exception.
  UniqueViolationException(super.message);
}

/// Thrown when there is an error with the data schema (data model).
///
/// Typically, there is a conflict between the data model defined in your code
/// (using `@Entity` classes) and the data model of the existing database file.
///
/// Read the [meta model docs](https://docs.objectbox.io/advanced/meta-model-ids-and-uids#resolving-meta-model-conflicts)
/// on why this can happen and how to resolve such conflicts.
class SchemaException extends ObjectBoxException {
  /// See [SchemaException].
  SchemaException(super.message);
}

/// Errors were detected in a database file, e.g. illegal values or structural
/// inconsistencies.
class DbFileCorruptException extends StorageException {
  /// See [DbFileCorruptException].
  DbFileCorruptException(super.message, super.errorCode);
}

/// Errors related to pages were detected in a database file, e.g. bad page refs
/// outside of the file.
class DbPagesCorruptException extends DbFileCorruptException {
  /// See [DbPagesCorruptException].
  DbPagesCorruptException(super.message, super.errorCode);
}

/// Thrown if `Query.findUnique()` is called, but the query matches more than
/// one object.
class NonUniqueResultException extends ObjectBoxException {
  /// See [NonUniqueResultException].
  NonUniqueResultException(super.message);
}

/// Passed as `debugFlags` when calling [Store.new] to enable debug options.
class DebugFlags {
  /// Log read transactions.
  static const int logTransactionsRead = 1;

  /// Log write transactions.
  static const int logTransactionsWrite = 2;

  /// Log queries.
  static const int logQueries = 4;

  /// Log parameters used in queries.
  static const int logQueryParameters = 8;

  /// Log async queue details.
  static const int logAsyncQueue = 16;

  /// Log cache hits.
  static const int logCacheHits = 32;

  /// Log all cache access.
  static const int logCacheAll = 64;

  /// Log tree API use.
  static const int logTree = 128;

  /// For a limited number of error conditions, this will try to print stack
  /// traces. Note: this is Linux-only, experimental, and has several
  /// limitations: The usefulness of these stack traces depends on several
  /// factors and might not be helpful at all.
  static const int logExceptionStackTrace = 256;

  /// Run a quick self-test to verify basic threading; somewhat paranoia to
  /// check the platform and the library setup.
  static const int runThreadingSelfTest = 512;
}
