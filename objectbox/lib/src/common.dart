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

/// A unique constraint would have been violated by this database operation.
class UniqueViolationException extends ObjectBoxException {
  /// Create a new exception.
  UniqueViolationException(String message) : super(message);
}

/// Flags to enable debug options when creating a [Store].
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
}
