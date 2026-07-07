import '../annotations.dart';
import '../modelinfo/model_hnsw_params.dart';
import 'bindings/bindings.dart';
import 'bindings/helpers.dart';

/// Utility functions for vectors and their distance, which is used by vector
/// search (see [HnswIndex]).
class VectorDistances {
  VectorDistances._();

  /// Returns if vector search, and thus this utility, is available in the
  /// loaded ObjectBox database library.
  static bool isAvailable() => C.has_feature(OBXFeature.VectorSearch);

  static void _checkAvailable() {
    if (!isAvailable()) {
      throw UnsupportedError(
        'Vector search is not available in the loaded ObjectBox database '
        'library.',
      );
    }
  }

  /// Calculates the distance of two given vectors, like it would be done when
  /// searching with a [VectorDistanceType] used by an [HnswIndex].
  ///
  /// The vectors must have the same number of elements. For
  /// [VectorDistanceType.geo] the first two elements are used (latitude and
  /// longitude).
  ///
  /// The returned distance measure is dependent on the distance [type], see
  /// the documentation of the [VectorDistanceType] values. Returns [double.nan]
  /// if the distance could not be calculated (e.g. vectors have not enough
  /// dimensions for the given type).
  ///
  /// See [distanceToRelevance] to convert the returned distance to a relevance
  /// score with a fixed range.
  static double distance(
    VectorDistanceType type,
    List<double> vector1,
    List<double> vector2,
  ) {
    _checkAvailable();
    if (vector1.length != vector2.length) {
      throw ArgumentError(
        'The vectors must have the same number of elements '
        '(${vector1.length} vs. ${vector2.length})',
      );
    }
    return withNativeFloats(
      vector1,
      (ptr1, size) => withNativeFloats(
        vector2,
        (ptr2, _) =>
            C.vector_distance_float32(type.toConstant(), ptr1, ptr2, size),
      ),
    );
  }

  /// Converts the given [distance] (a query score, see e.g.
  /// `Query.findWithScores` or [distance]) of the given [VectorDistanceType]
  /// to a relevance score.
  ///
  /// While the distance is potentially unbound (e.g. for
  /// [VectorDistanceType.euclidean] and [VectorDistanceType.dotProduct]) and
  /// its range depends on the distance type, the relevance score always has a
  /// fixed range from 0.0 (least relevant, farthest) to 1.0 (most relevant,
  /// nearest).
  ///
  /// Returns [double.nan] if the conversion is not supported for the given
  /// distance type (e.g. for [VectorDistanceType.geo]).
  static double distanceToRelevance(VectorDistanceType type, double distance) {
    _checkAvailable();
    return C.vector_distance_to_relevance(type.toConstant(), distance);
  }
}
