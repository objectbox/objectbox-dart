import 'query.dart';

/// Wraps a matching object and a score when using [Query.findWithScores].
class ObjectWithScore<T> {
  /// The object.
  final T object;

  /// The query score for the [object].
  ///
  /// The query score indicates some quality measurement.
  /// E.g. for vector nearest neighbor searches, the score is the distance to the given vector.
  final double score;

  /// Create result wrapper.
  ObjectWithScore(this.object, this.score);
}

/// Wraps the ID of a matching object and a score when using [Query.findIdsWithScores].
class IdWithScore {
  /// The object ID.
  final int id;

  /// The query score for the [id].
  ///
  /// The query score indicates some quality measurement.
  /// E.g. for vector nearest neighbor searches, the score is the distance to the given vector.
  final double score;

  /// Create result wrapper.
  IdWithScore(this.id, this.score);
}
