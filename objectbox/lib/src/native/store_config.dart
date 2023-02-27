part of 'store.dart';

/// Configuration of a [Store] containing everything required to obtain it
/// again, e.g. from another isolate.
class StoreConfiguration {
  /// The ID of the store.
  final int id;

  /// [Store._modelDefinition]
  final ModelDefinition modelDefinition;

  /// [Store.directoryPath]
  final String directoryPath;

  /// [Store._queriesCaseSensitiveDefault]
  final bool queriesCaseSensitiveDefault;

  /// Create a new [StoreConfiguration].
  StoreConfiguration._(this.id, this.modelDefinition, this.directoryPath,
      {required this.queriesCaseSensitiveDefault});
}
