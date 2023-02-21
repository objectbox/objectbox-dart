part of 'store.dart';

/// Configuration of a [Store] for use with [WeakStore].
class StoreConfiguration {
  /// [Store._modelDefinition]
  final ModelDefinition modelDefinition;

  /// [Store.directoryPath]
  final String directoryPath;

  /// [Store._queriesCaseSensitiveDefault]
  final bool queriesCaseSensitiveDefault;

  /// The ID of the store.
  final int id;

  /// Create a new [StoreConfiguration].
  StoreConfiguration(this.modelDefinition, this.directoryPath,
      this.queriesCaseSensitiveDefault, this.id);
}
