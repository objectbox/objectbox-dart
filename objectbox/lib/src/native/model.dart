import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../modelinfo/index.dart';
import 'bindings/bindings.dart';
import 'bindings/helpers.dart';

// ignore_for_file: public_member_api_docs

@internal
class Model {
  final Pointer<OBX_model> _cModel;

  Pointer<OBX_model> get ptr => _cModel;

  Model(ModelInfo model)
    : _cModel = checkObxPtr(C.model(), 'failed to create model') {
    try {
      model.entities.forEach(addEntity);

      C.model_last_entity_id(
        _cModel,
        model.lastEntityId.id,
        model.lastEntityId.uid,
      );
      C.model_last_relation_id(
        _cModel,
        model.lastRelationId.id,
        model.lastRelationId.uid,
      );
      C.model_last_index_id(
        _cModel,
        model.lastIndexId.id,
        model.lastIndexId.uid,
      );
    } catch (e) {
      C.model_free(_cModel);
      rethrow;
    }
  }

  void _check(int errorCode) {
    if (errorCode == OBX_SUCCESS) return;
    ObjectBoxNativeError(
      C.model_error_code(_cModel),
      dartStringFromC(C.model_error_message(_cModel)),
      'Model building failed',
    ).throwMapped();
  }

  void addEntity(ModelEntity entity) {
    // start entity
    final name = entity.name.toNativeUtf8();
    try {
      _check(C.model_entity(_cModel, name.cast(), entity.id.id, entity.id.uid));
    } finally {
      calloc.free(name);
    }

    if (entity.flags != 0) _check(C.model_entity_flags(_cModel, entity.flags));

    final externalName = entity.externalName?.toNativeUtf8();
    if (externalName != null) {
      try {
        _check(C.model_entity_external_name(_cModel, externalName.cast()));
      } finally {
        calloc.free(externalName);
      }
    }

    // add all properties
    entity.properties.forEach(addProperty);

    _check(
      C.model_entity_last_property_id(
        _cModel,
        entity.lastPropertyId.id,
        entity.lastPropertyId.uid,
      ),
    );

    entity.relations.forEach(addRelation);
  }

  void addProperty(ModelProperty prop) {
    final name = prop.name.toNativeUtf8();
    try {
      _check(
        C.model_property(
          _cModel,
          name.cast(),
          prop.type,
          prop.id.id,
          prop.id.uid,
        ),
      );

      if (prop.isRelation) {
        final relTarget = prop.relationTarget!.toNativeUtf8();
        try {
          _check(
            C.model_property_relation(
              _cModel,
              relTarget.cast(),
              prop.indexId!.id,
              prop.indexId!.uid,
            ),
          );
        } finally {
          calloc.free(relTarget);
        }
      } else if (prop.indexId != null) {
        _check(
          C.model_property_index_id(
            _cModel,
            prop.indexId!.id,
            prop.indexId!.uid,
          ),
        );
      }
    } finally {
      calloc.free(name);
    }

    if (prop.flags != 0) {
      _check(C.model_property_flags(_cModel, prop.flags));
    }

    final hnswParams = prop.hnswParams;
    if (hnswParams != null) {
      // Not set for an index with late init (set via Store.initHnswIndex)
      final dimensions = hnswParams.dimensions;
      if (dimensions != null) {
        _check(C.model_property_index_hnsw_dimensions(_cModel, dimensions));
      }
      // Set the build level first: for the C API the last call wins, so the
      // neighbors per node and indexing search count, if set, take precedence.
      if (hnswParams.buildLevel != null) {
        _check(
          C.model_property_index_hnsw_build_level(
            _cModel,
            hnswParams.buildLevel!,
          ),
        );
      }
      if (hnswParams.neighborsPerNode != null) {
        _check(
          C.model_property_index_hnsw_neighbors_per_node(
            _cModel,
            hnswParams.neighborsPerNode!,
          ),
        );
      }
      if (hnswParams.indexingSearchCount != null) {
        _check(
          C.model_property_index_hnsw_indexing_search_count(
            _cModel,
            hnswParams.indexingSearchCount!,
          ),
        );
      }
      if (hnswParams.flags != null) {
        _check(C.model_property_index_hnsw_flags(_cModel, hnswParams.flags!));
      }
      if (hnswParams.distanceType != null) {
        _check(
          C.model_property_index_hnsw_distance_type(
            _cModel,
            hnswParams.distanceType!,
          ),
        );
      }
      if (hnswParams.reparationBacklinkProbability != null) {
        _check(
          C.model_property_index_hnsw_reparation_backlink_probability(
            _cModel,
            hnswParams.reparationBacklinkProbability!,
          ),
        );
      }
      if (hnswParams.vectorCacheHintSizeKB != null) {
        _check(
          C.model_property_index_hnsw_vector_cache_hint_size_kb(
            _cModel,
            hnswParams.vectorCacheHintSizeKB!,
          ),
        );
      }
      if (hnswParams.quantization != null) {
        _check(
          C.model_property_index_hnsw_quantization(
            _cModel,
            hnswParams.quantization!,
          ),
        );
      }
      if (hnswParams.quantizationOversample != null) {
        _check(
          C.model_property_index_hnsw_quantization_oversample(
            _cModel,
            hnswParams.quantizationOversample!,
          ),
        );
      }
      if (hnswParams.quantizationRescoreFactor != null) {
        _check(
          C.model_property_index_hnsw_quantization_rescore_factor(
            _cModel,
            hnswParams.quantizationRescoreFactor!,
          ),
        );
      }
      if (hnswParams.searchLevel != null) {
        _check(
          C.model_property_index_hnsw_search_level(
            _cModel,
            hnswParams.searchLevel!,
          ),
        );
      }
      if (hnswParams.bruteForceMaxCandidates != null) {
        _check(
          C.model_property_index_hnsw_brute_force_max_candidates(
            _cModel,
            hnswParams.bruteForceMaxCandidates!,
          ),
        );
      }
      if (hnswParams.filteredSearchMaxNodes != null) {
        _check(
          C.model_property_index_hnsw_filtered_search_max_nodes(
            _cModel,
            hnswParams.filteredSearchMaxNodes!,
          ),
        );
      }
    }

    final externalType = prop.externalType;
    if (externalType != null) {
      _check(C.model_property_external_type(_cModel, externalType));
    }
    final externalName = prop.externalName?.toNativeUtf8();
    if (externalName != null) {
      try {
        _check(C.model_property_external_name(_cModel, externalName.cast()));
      } finally {
        calloc.free(externalName);
      }
    }
  }

  void addRelation(ModelRelation rel) {
    _check(
      C.model_relation(
        _cModel,
        rel.id.id,
        rel.id.uid,
        rel.targetId.id,
        rel.targetId.uid,
      ),
    );

    final name = rel.name.toNativeUtf8();
    try {
      _check(C.model_relation_name(_cModel, name.cast()));
    } finally {
      calloc.free(name);
    }

    if (rel.externalType != null) {
      _check(C.model_relation_external_type(_cModel, rel.externalType!));
    }
    final externalName = rel.externalName?.toNativeUtf8();
    if (externalName != null) {
      try {
        _check(C.model_relation_external_name(_cModel, externalName.cast()));
      } finally {
        calloc.free(externalName);
      }
    }
  }
}
