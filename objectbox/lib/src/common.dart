// TODO use pub_semver?
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
