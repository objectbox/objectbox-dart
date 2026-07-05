import 'package:meta/meta.dart';

import 'modelinfo/index.dart';

/// Configuration of a `Store` containing everything required to obtain it
/// again, e.g. from another isolate.
///
/// This is platform-independent (contains no FFI types), so it is shared
/// between the native and web implementations of the store.
class StoreConfiguration {
  /// The ID of the store.
  final int id;

  /// The ModelDefinition of the store.
  final ModelDefinition modelDefinition;

  /// Path to the database directory.
  final String directoryPath;

  /// Default value for the string query conditions `caseSensitive` argument.
  final bool queriesCaseSensitiveDefault;

  /// Create a new [StoreConfiguration]. Internal only: this constructor is not
  /// part of the public API and may change at any time.
  @internal
  StoreConfiguration(
      this.id,
      this.modelDefinition,
      this.directoryPath,
      // ignore: avoid_positional_boolean_parameters
      this.queriesCaseSensitiveDefault);
}
