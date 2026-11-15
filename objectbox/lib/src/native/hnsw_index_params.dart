import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:meta/meta.dart';

import '../annotations.dart';
import '../modelinfo/model_hnsw_params.dart';
import 'bindings/objectbox_c.dart';

/// The parameters of an HNSW index (vector search), like the ones of
/// [HnswIndex]; see there for details. Parameters that are `null` use their
/// defaults.
///
/// Used for the late init of an index (see `Store.initHnswIndex()`) and
/// returned by `Store.hnswIndexParams()`.
class HnswIndexParams {
  /// See [HnswIndex.dimensions]; required to initialize an index.
  ///
  /// Returned as 0 for an index with late init that was not initialized yet.
  final int dimensions;

  /// See [HnswIndex.neighborsPerNode].
  final int? neighborsPerNode;

  /// See [HnswIndex.indexingSearchCount].
  final int? indexingSearchCount;

  /// See [HnswIndex.flags].
  final HnswFlags? flags;

  /// See [HnswIndex.distanceType].
  final VectorDistanceType? distanceType;

  /// See [HnswIndex.reparationBacklinkProbability].
  final double? reparationBacklinkProbability;

  /// See [HnswIndex.vectorCacheHintSizeKB].
  final int? vectorCacheHintSizeKB;

  /// See [HnswIndex.quantization].
  final VectorQuantization? quantization;

  /// See [HnswIndex.quantizationOversample].
  final double? quantizationOversample;

  /// See [HnswIndex.quantizationRescoreFactor].
  final double? quantizationRescoreFactor;

  /// See [HnswIndex.searchLevel].
  final VectorSearchLevel? searchLevel;

  /// See [HnswIndex.buildLevel].
  ///
  /// Not returned by `Store.hnswIndexParams()`, which returns the
  /// [neighborsPerNode] and [indexingSearchCount] the level resolved to
  /// instead.
  final VectorBuildLevel? buildLevel;

  /// See [HnswIndex.bruteForceMaxCandidates].
  final int? bruteForceMaxCandidates;

  /// See [HnswIndex.filteredSearchMaxNodes].
  final int? filteredSearchMaxNodes;

  /// See [HnswIndex.randomSeed].
  final int? randomSeed;

  /// Creates parameters for an HNSW index; see [HnswIndex.new] for details.
  const HnswIndexParams({
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
    this.randomSeed,
  });

  @override
  String toString() =>
      'HnswIndexParams{dimensions: $dimensions'
      '${neighborsPerNode != null ? ', neighborsPerNode: $neighborsPerNode' : ''}'
      '${indexingSearchCount != null ? ', indexingSearchCount: $indexingSearchCount' : ''}'
      '${flags != null ? ', flags: ${flags!.toFlags()}' : ''}'
      '${distanceType != null ? ', distanceType: ${distanceType!.name}' : ''}'
      '${reparationBacklinkProbability != null ? ', reparationBacklinkProbability: $reparationBacklinkProbability' : ''}'
      '${vectorCacheHintSizeKB != null ? ', vectorCacheHintSizeKB: $vectorCacheHintSizeKB' : ''}'
      '${quantization != null ? ', quantization: ${quantization!.name}' : ''}'
      '${quantizationOversample != null ? ', quantizationOversample: $quantizationOversample' : ''}'
      '${quantizationRescoreFactor != null ? ', quantizationRescoreFactor: $quantizationRescoreFactor' : ''}'
      '${searchLevel != null ? ', searchLevel: ${searchLevel!.name}' : ''}'
      '${buildLevel != null ? ', buildLevel: ${buildLevel!.name}' : ''}'
      '${bruteForceMaxCandidates != null ? ', bruteForceMaxCandidates: $bruteForceMaxCandidates' : ''}'
      '${filteredSearchMaxNodes != null ? ', filteredSearchMaxNodes: $filteredSearchMaxNodes' : ''}'
      '${randomSeed != null ? ', randomSeed: $randomSeed' : ''}'
      '}';
}

/// What `Store.initHnswIndex()` does with the existing objects of the type.
///
/// Caution with Sync: for a sync-enabled type, the removing modes remove the
/// objects like other changes do, so if a sync client is running, the removals
/// are synced to the server (and thus to other clients).
enum HnswInitMode {
  /// Keeps the objects: indexes them if needed (the first init or other
  /// parameters requiring re-indexing).
  ///
  /// Objects whose vectors do not fit the parameters (fewer dimensions) are
  /// kept, but not indexed (and not counted); consider
  /// [removeAllObjectsOnReindex] for those.
  keepObjects,

  /// Removes all objects of the type instead of indexing them (the first init
  /// or other parameters requiring re-indexing), e.g. if their vectors would
  /// not fit the parameters anyway (other dimensions or embedding model); keeps
  /// them otherwise, e.g. with the parameters in effect.
  ///
  /// Removing all objects at once is much cheaper than indexing them (and than
  /// removing them one by one).
  removeAllObjectsOnReindex,

  /// Always removes all objects of the type, also with the parameters in
  /// effect.
  removeAllObjectsAlways,
}

/// What `Store.initHnswIndex()` did; e.g. if it removed the objects, the app
/// may want to recompute their vectors.
class HnswInitResult {
  final int _flags;

  /// The number of indexed objects (those with vectors fitting the dimensions)
  /// or removed objects.
  final int objectCount;

  /// Creates a result from the OBXHnswInitResult bit flags of the C API.
  @internal
  HnswInitResult.fromNative(this._flags, this.objectCount);

  /// If nothing changed, e.g. the parameters were already in effect.
  bool get unchanged => _flags == 0;

  /// If the parameters were set (and persisted): the first init or other
  /// parameters.
  bool get paramsChanged => _flags & OBXHnswInitResult.ParamsChanged != 0;

  /// If objects of the type were indexed; see [objectCount].
  bool get objectsIndexed => _flags & OBXHnswInitResult.ObjectsIndexed != 0;

  /// If objects of the type were removed (see [HnswInitMode]); see
  /// [objectCount].
  bool get objectsRemoved => _flags & OBXHnswInitResult.ObjectsRemoved != 0;

  @override
  String toString() =>
      'HnswInitResult{paramsChanged: $paramsChanged, '
      'objectsIndexed: $objectsIndexed, objectsRemoved: $objectsRemoved, '
      'objectCount: $objectCount}';
}

/// Adds mapping to internal constants.
extension HnswInitModeConstant on HnswInitMode {
  /// Convert to internal constant value.
  int toConstant() => switch (this) {
    HnswInitMode.keepObjects => OBXHnswInitMode.KeepObjects,
    HnswInitMode.removeAllObjectsOnReindex =>
      OBXHnswInitMode.RemoveAllObjectsOnReindex,
    HnswInitMode.removeAllObjectsAlways =>
      OBXHnswInitMode.RemoveAllObjectsAlways,
  };
}

// The HnswParams FlatBuffers table is built and read by hand, as its schema
// (hnsw-params.fbs) is internal to the ObjectBox database (not part of the
// public C API) and the code generated by `flatc --dart` is not usable as is,
// e.g. it can not read combined bit flags. For details, see the "FlatBuffers
// Tables of the C API" section of AGENTS.md in the repository root.
//
// The field indices and types of the HnswParams table; keep them in sync with
// hnsw-params.fbs.
const _fieldDimensions = 0; // uint
const _fieldNeighborsPerNode = 1; // uint
const _fieldIndexingSearchCount = 2; // uint
const _fieldFlags = 3; // HnswFlags: uint
const _fieldDistanceType = 4; // HnswDistanceType: ushort
const _fieldReparationBacklinkProbability = 5; // float
const _fieldVectorCacheHintSizeKB = 6; // ulong
const _fieldQuantization = 7; // HnswQuantization: ushort
const _fieldQuantizationOversample = 8; // float
const _fieldQuantizationRescoreFactor = 9; // float
const _fieldSearchLevel = 10; // ubyte
const _fieldBruteForceMaxCandidates = 11; // uint
const _fieldFilteredSearchMaxNodes = 12; // uint
const _fieldBuildLevel = 13; // ubyte
const _fieldRandomSeed = 14; // ulong
const _fieldCount = 15;

/// The offset of a field in the vtable of a FlatBuffers table, as used by
/// readers.
int _vTableOffset(int fieldIndex) => 4 + 2 * fieldIndex;

/// Validates [params] and returns them as a FlatBuffers HnswParams table, as
/// expected by the C API.
///
/// The values of the C API constants (distance type, flags, quantization,
/// levels) are the same as the ones of the FlatBuffers enums.
Uint8List hnswIndexParamsToFlatBuffers(HnswIndexParams params) {
  if (params.dimensions <= 0) {
    throw ArgumentError.value(
      params.dimensions,
      'dimensions',
      'must be 1 or greater',
    );
  }
  // Re-use the validation and conversion of the annotation values.
  final model = ModelHnswParams.fromAnnotation(
    HnswIndex(
      dimensions: params.dimensions,
      neighborsPerNode: params.neighborsPerNode,
      indexingSearchCount: params.indexingSearchCount,
      flags: params.flags,
      distanceType: params.distanceType,
      reparationBacklinkProbability: params.reparationBacklinkProbability,
      vectorCacheHintSizeKB: params.vectorCacheHintSizeKB,
      quantization: params.quantization,
      quantizationOversample: params.quantizationOversample,
      quantizationRescoreFactor: params.quantizationRescoreFactor,
      searchLevel: params.searchLevel,
      buildLevel: params.buildLevel,
      bruteForceMaxCandidates: params.bruteForceMaxCandidates,
      filteredSearchMaxNodes: params.filteredSearchMaxNodes,
      randomSeed: params.randomSeed,
    ),
  );
  final fbb = fb.Builder(initialSize: 128);
  fbb.startTable(_fieldCount);
  // Values that are null are not added (absent: not set).
  fbb.addUint32(_fieldDimensions, model.dimensions);
  fbb.addUint32(_fieldNeighborsPerNode, model.neighborsPerNode);
  fbb.addUint32(_fieldIndexingSearchCount, model.indexingSearchCount);
  fbb.addUint32(_fieldFlags, model.flags);
  fbb.addUint16(_fieldDistanceType, model.distanceType);
  fbb.addFloat32(
    _fieldReparationBacklinkProbability,
    model.reparationBacklinkProbability,
  );
  fbb.addUint64(_fieldVectorCacheHintSizeKB, model.vectorCacheHintSizeKB);
  fbb.addUint16(_fieldQuantization, model.quantization);
  fbb.addFloat32(_fieldQuantizationOversample, model.quantizationOversample);
  fbb.addFloat32(
    _fieldQuantizationRescoreFactor,
    model.quantizationRescoreFactor,
  );
  fbb.addUint8(_fieldSearchLevel, model.searchLevel);
  fbb.addUint32(_fieldBruteForceMaxCandidates, model.bruteForceMaxCandidates);
  fbb.addUint32(_fieldFilteredSearchMaxNodes, model.filteredSearchMaxNodes);
  fbb.addUint8(_fieldBuildLevel, model.buildLevel);
  fbb.addUint64(_fieldRandomSeed, model.randomSeed);
  fbb.finish(fbb.endTable());
  return fbb.buffer;
}

/// Reads a FlatBuffers HnswParams table returned by the C API.
///
/// Values that are not set (absent or 0) are returned as `null`, except for
/// the dimensions (0 if not set).
HnswIndexParams hnswIndexParamsFromFlatBuffers(Uint8List bytes) {
  final buffer = fb.BufferContext.fromBytes(bytes);
  final table = buffer.derefObject(0);
  int? uint32(int field) {
    final value = const fb.Uint32Reader().vTableGet(
      buffer,
      table,
      _vTableOffset(field),
      0,
    );
    return value == 0 ? null : value;
  }

  int? uint16(int field) {
    final value = const fb.Uint16Reader().vTableGet(
      buffer,
      table,
      _vTableOffset(field),
      0,
    );
    return value == 0 ? null : value;
  }

  int? uint8(int field) {
    final value = const fb.Uint8Reader().vTableGet(
      buffer,
      table,
      _vTableOffset(field),
      0,
    );
    return value == 0 ? null : value;
  }

  int? uint64(int field) {
    final value = const fb.Uint64Reader().vTableGet(
      buffer,
      table,
      _vTableOffset(field),
      0,
    );
    return value == 0 ? null : value;
  }

  double? float32(int field) => const fb.Float32Reader().vTableGetNullable(
    buffer,
    table,
    _vTableOffset(field),
  );

  final flags = uint32(_fieldFlags);
  final distanceType = uint16(_fieldDistanceType);
  final quantization = uint16(_fieldQuantization);
  final searchLevel = uint8(_fieldSearchLevel);
  final buildLevel = uint8(_fieldBuildLevel);
  final quantizationOversample = float32(_fieldQuantizationOversample);
  final quantizationRescoreFactor = float32(_fieldQuantizationRescoreFactor);
  return HnswIndexParams(
    dimensions: uint32(_fieldDimensions) ?? 0,
    neighborsPerNode: uint32(_fieldNeighborsPerNode),
    indexingSearchCount: uint32(_fieldIndexingSearchCount),
    flags: flags != null ? _hnswFlagsFrom(flags) : null,
    distanceType: _fromConstant(
      VectorDistanceType.values,
      (t) => t.toConstant(),
      distanceType,
    ),
    reparationBacklinkProbability: float32(_fieldReparationBacklinkProbability),
    vectorCacheHintSizeKB: uint64(_fieldVectorCacheHintSizeKB),
    quantization: _fromConstant(
      VectorQuantization.values,
      (q) => q.toConstant(),
      quantization,
    ),
    quantizationOversample:
        quantizationOversample == 0 ? null : quantizationOversample,
    quantizationRescoreFactor:
        quantizationRescoreFactor == 0 ? null : quantizationRescoreFactor,
    searchLevel: _fromConstant(
      VectorSearchLevel.values,
      (l) => l.toConstant(),
      searchLevel,
    ),
    buildLevel: _fromConstant(
      VectorBuildLevel.values,
      (l) => l.toConstant(),
      buildLevel,
    ),
    bruteForceMaxCandidates: uint32(_fieldBruteForceMaxCandidates),
    filteredSearchMaxNodes: uint32(_fieldFilteredSearchMaxNodes),
    randomSeed: uint64(_fieldRandomSeed),
  );
}

HnswFlags _hnswFlagsFrom(int flags) => HnswFlags(
  debugLogs: flags & OBXHnswFlags.DebugLogs != 0,
  debugLogsDetailed: flags & OBXHnswFlags.DebugLogsDetailed != 0,
  vectorCacheSimdPaddingOff:
      flags & OBXHnswFlags.VectorCacheSimdPaddingOff != 0,
  lateInit: flags & OBXHnswFlags.LateInit != 0,
);

/// Returns the value of [values] that maps to [constant], or null if there is
/// none (e.g. a value added by a newer version of the database library).
T? _fromConstant<T>(
  List<T> values,
  int Function(T value) toConstant,
  int? constant,
) {
  if (constant == null) return null;
  for (final value in values) {
    if (toConstant(value) == constant) return value;
  }
  return null;
}
