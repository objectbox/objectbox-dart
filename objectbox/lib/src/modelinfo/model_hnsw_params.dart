import '../annotations.dart';
import '../native/bindings/objectbox_c.dart';

/// Describes HNSW index parameters for a float vector property.
class ModelHnswParams {
  /// See [HnswIndex.dimensions].
  final int dimensions;

  /// See [HnswIndex.neighborsPerNode].
  final int? neighborsPerNode;

  /// See [HnswIndex.indexingSearchCount].
  final int? indexingSearchCount;

  /// See [HnswIndex.flags].
  final int? flags;

  /// See [HnswIndex.distanceType].
  final int? distanceType;

  /// See [HnswIndex.reparationBacklinkProbability].
  final double? reparationBacklinkProbability;

  /// See [HnswIndex.vectorCacheHintSizeKB].
  final int? vectorCacheHintSizeKB;

  /// Create an instance. For use from generated code.
  ModelHnswParams({
    required this.dimensions,
    this.neighborsPerNode,
    this.indexingSearchCount,
    this.flags,
    this.distanceType,
    this.reparationBacklinkProbability,
    this.vectorCacheHintSizeKB,
  });

  /// If [condition] does not evaluate to `true` throws an [ArgumentError]
  /// using the given [argument], [name] and [message].
  static void _checkArgument({
    required Object argument,
    required bool condition,
    required String name,
    required String message,
  }) {
    if (!condition) {
      throw ArgumentError.value(argument, name, message);
    }
  }

  /// Create with values from an [HnswIndex] annotation.
  static ModelHnswParams fromAnnotation(HnswIndex hnsw) {
    // Reject illegal configuration values during a generator run already,
    // otherwise would error at runtime (which might not be easily attributable,
    // see model.dart).
    // See allowed ranges in objectbox-c/src/model.cpp
    _checkArgument(
      argument: hnsw.dimensions,
      condition: hnsw.dimensions > 0,
      name: "dimensions",
      message: "must be 1 or greater",
    );
    final neighborsPerNode = hnsw.neighborsPerNode;
    if (neighborsPerNode != null) {
      _checkArgument(
        argument: neighborsPerNode,
        condition: neighborsPerNode > 0,
        name: "neighborsPerNode",
        message: "must be 1 or greater",
      );
    }
    final indexingSearchCount = hnsw.indexingSearchCount;
    if (indexingSearchCount != null) {
      _checkArgument(
        argument: indexingSearchCount,
        condition: indexingSearchCount > 0,
        name: "indexingSearchCount",
        message: "must be 1 or greater",
      );
    }
    final reparationBacklinkProbability = hnsw.reparationBacklinkProbability;
    if (reparationBacklinkProbability != null) {
      // The C API allows values bigger than 1.0, but internally everything
      // above 0.999 is just mapped to "always": so restrict to max 1.0.
      _checkArgument(
        argument: reparationBacklinkProbability,
        condition:
            reparationBacklinkProbability >= 0.0 &&
            reparationBacklinkProbability <= 1.0,
        name: "reparationBacklinkProbability",
        message: "must be between 0.0 or 1.0",
      );
    }
    final vectorCacheHintSizeKB = hnsw.vectorCacheHintSizeKB;
    if (vectorCacheHintSizeKB != null) {
      _checkArgument(
        argument: vectorCacheHintSizeKB,
        condition: vectorCacheHintSizeKB > 0,
        name: "vectorCacheHintSizeKB",
        message: "must be 1 or greater",
      );
    }
    return ModelHnswParams(
      dimensions: hnsw.dimensions,
      neighborsPerNode: neighborsPerNode,
      indexingSearchCount: indexingSearchCount,
      flags: hnsw.flags?.toFlags(),
      distanceType: hnsw.distanceType?.toConstant(),
      reparationBacklinkProbability: reparationBacklinkProbability,
      vectorCacheHintSizeKB: vectorCacheHintSizeKB,
    );
  }

  /// Create from a string map created by [toMap].
  static ModelHnswParams? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return ModelHnswParams(
      dimensions: map["dimensions"] as int,
      neighborsPerNode: map["neighborsPerNode"] as int?,
      indexingSearchCount: map["indexingSearchCount"] as int?,
      flags: map["flags"] as int?,
      distanceType: map["distanceType"] as int?,
      reparationBacklinkProbability:
          map["reparationBacklinkProbability"] as double?,
      vectorCacheHintSizeKB: map["vectorCacheHintSizeKB"] as int?,
    );
  }

  /// Convert to string map to store in entity info cache file.
  Map<String, Object> toMap() {
    final map = <String, Object>{};
    map["dimensions"] = dimensions;
    if (neighborsPerNode != null) {
      map["neighborsPerNode"] = neighborsPerNode!;
    }
    if (indexingSearchCount != null) {
      map["indexingSearchCount"] = indexingSearchCount!;
    }
    if (flags != null) {
      map["flags"] = flags!;
    }
    if (distanceType != null) {
      map["distanceType"] = distanceType!;
    }
    if (reparationBacklinkProbability != null) {
      map["reparationBacklinkProbability"] = reparationBacklinkProbability!;
    }
    if (vectorCacheHintSizeKB != null) {
      map["vectorCacheHintSizeKB"] = vectorCacheHintSizeKB!;
    }
    return map;
  }

  /// Convert to code string for generated code.
  String toCodeString(String libraryPrefix) {
    var code = StringBuffer("$libraryPrefix.ModelHnswParams(");
    // Note: Dart does not care about trailing commas
    code.write("dimensions: $dimensions, ");
    if (neighborsPerNode != null) {
      code.write("neighborsPerNode: $neighborsPerNode, ");
    }
    if (indexingSearchCount != null) {
      code.write("indexingSearchCount: $indexingSearchCount, ");
    }
    if (flags != null) {
      code.write("flags: $flags, ");
    }
    if (distanceType != null) {
      code.write("distanceType: $distanceType, ");
    }
    if (reparationBacklinkProbability != null) {
      code.write(
        "reparationBacklinkProbability: $reparationBacklinkProbability, ",
      );
    }
    if (vectorCacheHintSizeKB != null) {
      code.write("vectorCacheHintSizeKB: $vectorCacheHintSizeKB, ");
    }
    code.write(")");
    return code.toString();
  }
}

/// Adds mapping to internal flags.
extension ModelHnswFlags on HnswFlags {
  /// Convert to internal flags.
  int toFlags() {
    int flags = 0;
    if (debugLogs) {
      flags |= OBXHnswFlags.DebugLogs;
    }
    if (debugLogsDetailed) {
      flags |= OBXHnswFlags.DebugLogsDetailed;
    }
    if (vectorCacheSimdPaddingOff) {
      flags |= OBXHnswFlags.VectorCacheSimdPaddingOff;
    }
    if (reparationLimitCandidates) {
      flags |= OBXHnswFlags.ReparationLimitCandidates;
    }
    return flags;
  }
}

/// Adds mapping to internal constants.
extension ModelVectorDistanceType on VectorDistanceType {
  /// Convert to internal constant value.
  int toConstant() => switch (this) {
    VectorDistanceType.euclidean => OBXVectorDistanceType.Euclidean,
    VectorDistanceType.cosine => OBXVectorDistanceType.Cosine,
    VectorDistanceType.dotProduct => OBXVectorDistanceType.DotProduct,
    VectorDistanceType.dotProductNonNormalized =>
      OBXVectorDistanceType.DotProductNonNormalized,
    VectorDistanceType.geo => OBXVectorDistanceType.Geo,
  };
}
