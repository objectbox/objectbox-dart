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
  ModelHnswParams(
      {required this.dimensions,
      this.neighborsPerNode,
      this.indexingSearchCount,
      this.flags,
      this.distanceType,
      this.reparationBacklinkProbability,
      this.vectorCacheHintSizeKB});

  /// Create with values from an [HnswIndex] annotation.
  ModelHnswParams.fromAnnotation(HnswIndex hnsw)
      : this(
            dimensions: hnsw.dimensions,
            neighborsPerNode: hnsw.neighborsPerNode,
            indexingSearchCount: hnsw.indexingSearchCount,
            flags: hnsw.flags?.toFlags(),
            distanceType: hnsw.distanceType?.toConstant(),
            reparationBacklinkProbability: hnsw.reparationBacklinkProbability,
            vectorCacheHintSizeKB: hnsw.vectorCacheHintSizeKB);

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
          "reparationBacklinkProbability: $reparationBacklinkProbability, ");
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
extension ModelHnswDistanceType on HnswDistanceType {
  /// Convert to internal constant value.
  int toConstant() {
    if (this == HnswDistanceType.euclidean) {
      return OBXHnswDistanceType.Euclidean;
    } else {
      throw ArgumentError.value(this, "distanceType");
    }
  }
}
