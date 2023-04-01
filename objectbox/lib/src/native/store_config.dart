part of 'store.dart';

/// Configuration of a [Store] containing everything required to obtain it
/// again, e.g. from another isolate.
class StoreConfiguration {
  /// The ID of the store.
  final int id;

  /// The ModelDefinition of the store.
  final ModelDefinition modelDefinition;

  /// Path to the database directory.
  final String directoryPath;

  /// Default value for the string query conditions [caseSensitive] argument.
  final bool queriesCaseSensitiveDefault;

  /// Create a new [StoreConfiguration].
  StoreConfiguration._(this.id, this.modelDefinition, this.directoryPath,
      this.queriesCaseSensitiveDefault);
}
