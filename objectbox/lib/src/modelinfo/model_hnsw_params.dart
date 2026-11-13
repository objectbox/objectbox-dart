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

  /// See [HnswIndex.quantization].
  final int? quantization;

  /// See [HnswIndex.quantizationOversample].
  final double? quantizationOversample;

  /// See [HnswIndex.quantizationRescoreFactor].
  final double? quantizationRescoreFactor;

  /// See [HnswIndex.searchLevel].
  final int? searchLevel;

  /// See [HnswIndex.buildLevel].
  final int? buildLevel;

  /// See [HnswIndex.bruteForceMaxCandidates].
  final int? bruteForceMaxCandidates;

  /// See [HnswIndex.filteredSearchMaxNodes].
  final int? filteredSearchMaxNodes;

  /// Create an instance. For use from generated code.
  ModelHnswParams({
    required this.dimensions,
    this.neighborsPerNode,
    this.indexingSearchCount,
    this.flags,
    this.distanceType,
    this.reparationBacklinkProbability,
    this.vectorCacheHintSizeKB,
    this.quantization,
    this.quantizationOversample,
    this.quantizationRescoreFactor,
    this.searchLevel,
    this.buildLevel,
    this.bruteForceMaxCandidates,
    this.filteredSearchMaxNodes,
  });

  /// The max value of the C API's uint32_t parameters.
  static const _maxUint32 = 0xFFFFFFFF;

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
    final quantizationOversample = hnsw.quantizationOversample;
    if (quantizationOversample != null) {
      _checkArgument(
        argument: quantizationOversample,
        condition: quantizationOversample >= 1.0,
        name: "quantizationOversample",
        message: "must be 1.0 or greater",
      );
    }
    final quantizationRescoreFactor = hnsw.quantizationRescoreFactor;
    if (quantizationRescoreFactor != null) {
      _checkArgument(
        argument: quantizationRescoreFactor,
        condition: quantizationRescoreFactor >= 1.0,
        name: "quantizationRescoreFactor",
        message: "must be 1.0 or greater",
      );
    }
    final bruteForceMaxCandidates = hnsw.bruteForceMaxCandidates;
    if (bruteForceMaxCandidates != null) {
      _checkArgument(
        argument: bruteForceMaxCandidates,
        condition:
            bruteForceMaxCandidates > 0 &&
            bruteForceMaxCandidates <= _maxUint32,
        name: "bruteForceMaxCandidates",
        message: "must be between 1 and $_maxUint32",
      );
    }
    final filteredSearchMaxNodes = hnsw.filteredSearchMaxNodes;
    if (filteredSearchMaxNodes != null) {
      _checkArgument(
        argument: filteredSearchMaxNodes,
        condition:
            filteredSearchMaxNodes > 0 && filteredSearchMaxNodes <= _maxUint32,
        name: "filteredSearchMaxNodes",
        message: "must be between 1 and $_maxUint32",
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
      quantization: hnsw.quantization?.toConstant(),
      quantizationOversample: quantizationOversample,
      quantizationRescoreFactor: quantizationRescoreFactor,
      searchLevel: hnsw.searchLevel?.toConstant(),
      buildLevel: hnsw.buildLevel?.toConstant(),
      bruteForceMaxCandidates: bruteForceMaxCandidates,
      filteredSearchMaxNodes: filteredSearchMaxNodes,
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
      quantization: map["quantization"] as int?,
      quantizationOversample: map["quantizationOversample"] as double?,
      quantizationRescoreFactor: map["quantizationRescoreFactor"] as double?,
      searchLevel: map["searchLevel"] as int?,
      buildLevel: map["buildLevel"] as int?,
      bruteForceMaxCandidates: map["bruteForceMaxCandidates"] as int?,
      filteredSearchMaxNodes: map["filteredSearchMaxNodes"] as int?,
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
    if (quantization != null) {
      map["quantization"] = quantization!;
    }
    if (quantizationOversample != null) {
      map["quantizationOversample"] = quantizationOversample!;
    }
    if (quantizationRescoreFactor != null) {
      map["quantizationRescoreFactor"] = quantizationRescoreFactor!;
    }
    if (searchLevel != null) {
      map["searchLevel"] = searchLevel!;
    }
    if (buildLevel != null) {
      map["buildLevel"] = buildLevel!;
    }
    if (bruteForceMaxCandidates != null) {
      map["bruteForceMaxCandidates"] = bruteForceMaxCandidates!;
    }
    if (filteredSearchMaxNodes != null) {
      map["filteredSearchMaxNodes"] = filteredSearchMaxNodes!;
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
    if (quantization != null) {
      code.write("quantization: $quantization, ");
    }
    if (quantizationOversample != null) {
      code.write("quantizationOversample: $quantizationOversample, ");
    }
    if (quantizationRescoreFactor != null) {
      code.write("quantizationRescoreFactor: $quantizationRescoreFactor, ");
    }
    if (searchLevel != null) {
      code.write("searchLevel: $searchLevel, ");
    }
    if (buildLevel != null) {
      code.write("buildLevel: $buildLevel, ");
    }
    if (bruteForceMaxCandidates != null) {
      code.write("bruteForceMaxCandidates: $bruteForceMaxCandidates, ");
    }
    if (filteredSearchMaxNodes != null) {
      code.write("filteredSearchMaxNodes: $filteredSearchMaxNodes, ");
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

/// Adds mapping to internal constants.
extension ModelVectorQuantization on VectorQuantization {
  /// Convert to internal constant value.
  int toConstant() => switch (this) {
    VectorQuantization.none => OBXHnswQuantType.None,
    VectorQuantization.turboQuant1 => OBXHnswQuantType.TurboQuant1,
    VectorQuantization.turboQuant1_5 => OBXHnswQuantType.TurboQuant1_5,
    VectorQuantization.turboQuant2 => OBXHnswQuantType.TurboQuant2,
    VectorQuantization.turboQuant3 => OBXHnswQuantType.TurboQuant3,
    VectorQuantization.turboQuant4 => OBXHnswQuantType.TurboQuant4,
    VectorQuantization.scalarQuant8 => OBXHnswQuantType.ScalarQuant8,
  };
}

/// Adds mapping to internal constants.
extension ModelVectorSearchLevel on VectorSearchLevel {
  /// Convert to internal constant value.
  int toConstant() => switch (this) {
    VectorSearchLevel.l1Fastest => OBXHnswSearchLevel.L1_Fastest,
    VectorSearchLevel.l2VeryFast => OBXHnswSearchLevel.L2_VeryFast,
    VectorSearchLevel.l3Fast => OBXHnswSearchLevel.L3_Fast,
    VectorSearchLevel.l4Balanced => OBXHnswSearchLevel.L4_Balanced,
    VectorSearchLevel.l5BalancedQuality =>
      OBXHnswSearchLevel.L5_BalancedQuality,
    VectorSearchLevel.l6Quality => OBXHnswSearchLevel.L6_Quality,
    VectorSearchLevel.l7QualityHigh => OBXHnswSearchLevel.L7_QualityHigh,
    VectorSearchLevel.l8QualityHigher => OBXHnswSearchLevel.L8_QualityHigher,
    VectorSearchLevel.l9QualityUltra => OBXHnswSearchLevel.L9_QualityUltra,
    VectorSearchLevel.l10QualityMax => OBXHnswSearchLevel.L10_QualityMax,
  };
}

/// Adds mapping to internal constants.
extension ModelVectorBuildLevel on VectorBuildLevel {
  /// Convert to internal constant value.
  int toConstant() => switch (this) {
    VectorBuildLevel.l1Fastest => OBXHnswBuildLevel.L1_Fastest,
    VectorBuildLevel.l2VeryFast => OBXHnswBuildLevel.L2_VeryFast,
    VectorBuildLevel.l3Fast => OBXHnswBuildLevel.L3_Fast,
    VectorBuildLevel.l4Balanced => OBXHnswBuildLevel.L4_Balanced,
    VectorBuildLevel.l5BalancedQuality => OBXHnswBuildLevel.L5_BalancedQuality,
    VectorBuildLevel.l6Quality => OBXHnswBuildLevel.L6_Quality,
    VectorBuildLevel.l7QualityHigh => OBXHnswBuildLevel.L7_QualityHigh,
    VectorBuildLevel.l8QualityHigher => OBXHnswBuildLevel.L8_QualityHigher,
    VectorBuildLevel.l9QualityUltra => OBXHnswBuildLevel.L9_QualityUltra,
    VectorBuildLevel.l10QualityMax => OBXHnswBuildLevel.L10_QualityMax,
  };
}
