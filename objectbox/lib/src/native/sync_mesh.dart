import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings/bindings.dart';
import 'bindings/helpers.dart';

/// State of a [MeshSync] as returned by [MeshSync.state].
enum MeshState {
  /// State is unknown, e.g. the C-API reported a state that's not recognized
  /// yet (or the mesh is no longer available).
  unknown,

  /// Created but not started yet.
  created,

  /// Discovery is active (not enough peers connected yet).
  discovering,

  /// Fully connected (enough peers connected).
  fullyConnected,

  /// Stopped.
  stopped,

  /// Stopped and being torn down.
  dead
}

/// Mesh sync statistics counters, useful for testing and diagnostics.
///
/// Read a counter value with [MeshSync.stats].
enum MeshStats {
  /// Number of peers discovered.
  peersDiscovered(OBXMeshStats.peersDiscovered),

  /// Number of peers connected.
  peersConnected(OBXMeshStats.peersConnected),

  /// Number of peers disconnected.
  peersDisconnected(OBXMeshStats.peersDisconnected),

  /// Number of peer connection attempts that failed.
  peerConnectionsFailed(OBXMeshStats.peerConnectionsFailed),

  /// Number of peers lost (no longer available after discovery).
  peersLost(OBXMeshStats.peersLost),

  /// Number of messages received.
  messagesReceived(OBXMeshStats.messagesReceived),

  /// Number of messages sent.
  messagesSent(OBXMeshStats.messagesSent),

  /// Number of TX IDs announced.
  txIdsAnnounced(OBXMeshStats.txIdsAnnounced),

  /// Number of TX IDs requested (sent in TxLogRequest messages).
  txIdsRequested(OBXMeshStats.txIdsRequested),

  /// Number of TX IDs received.
  txIdsReceived(OBXMeshStats.txIdsReceived),

  /// Number of TX logs sent (in TxLogData messages).
  txLogsSent(OBXMeshStats.txLogsSent),

  /// Number of TX logs received and stored (from TxLogData messages).
  txLogsReceived(OBXMeshStats.txLogsReceived),

  /// Number of TX logs applied to the local DB.
  txLogsApplied(OBXMeshStats.txLogsApplied),

  /// Number of protocol errors.
  protocolErrors(OBXMeshStats.protocolErrors),

  /// Number of general errors.
  generalErrors(OBXMeshStats.generalErrors),

  /// Number of peers evicted to make room for newcomers.
  peersEvicted(OBXMeshStats.peersEvicted),

  /// Number of discoveries of our own peer ID prefix that were ignored.
  selfDiscoveriesIgnored(OBXMeshStats.selfDiscoveriesIgnored);

  /// The OBXMeshStats counter type ID passed to the C-API.
  final int _id;

  const MeshStats(this._id);
}

/// Configuration of a peer-to-peer mesh sync.
///
/// A mesh sync enables peer-to-peer (P2P) synchronization between sync clients
/// without a central server. Pass an instance to a `SyncClient` constructor
/// (via its `mesh` parameter) to attach a mesh sync to the client; it starts
/// and stops together with the client. Query the running mesh via the client's
/// `mesh` property.
///
/// Only [meshId] is required; all other values are optional and fall back to
/// the defaults of the ObjectBox runtime library when left `null`.
class MeshConfig {
  /// The mesh network identifier (required); nodes with different IDs ignore
  /// each other.
  final String meshId;

  /// Maximum number of simultaneous connections a peer can have to other peers
  /// (default: 3).
  ///
  /// The default of 3 already provides mesh resilience through alternative
  /// paths. 4 may give better fault tolerance, but at the cost of more radio
  /// activity. Values above 4 are not recommended. 2 is typically not
  /// recommended unless you run into severe radio limitations. 1 would be a
  /// rare special case if you only want to create pairs, not a mesh.
  final int? maxConnectionCount;

  /// Backoff time in milliseconds before retrying a failed connection
  /// (default: 10000).
  final int? backoffMillis;

  /// Backoff time in milliseconds between peer evictions (default: 30000).
  ///
  /// When an incoming peer has 0 connections, but this peer is at
  /// [maxConnectionCount], this peer ends a connection to an existing peer, it
  /// "evicts" that peer, to make room. This backoff prevents frequent
  /// evictions.
  final int? evictionBackoffMillis;

  /// Seed for the random engine; 0 means use the current time (default: 0).
  final int? randomSeed;

  /// Timeout in milliseconds for a TX request from a peer before retrying from
  /// another (default: 5000).
  final int? requestTimeoutMillis;

  /// Delay in milliseconds before advertising starts after the mesh sync starts
  /// (default: 2000).
  ///
  /// Discovery always starts immediately; advertising is delayed to "stretch
  /// out" radio activity.
  final int? advertisingDelayMillis;

  /// Base delay in milliseconds before retrying advertising after a network
  /// failed to start it (default: 5000).
  ///
  /// A network may fail to start advertising (e.g. missing permissions);
  /// advertising is then retried with exponential backoff (doubling up to
  /// [advertisingRetryMaxMillis]) because permissions may be granted later at
  /// runtime. Must be positive.
  final int? advertisingRetryMillis;

  /// Upper bound in milliseconds for the advertising retry backoff
  /// (default: 60000). Must be >= [advertisingRetryMillis].
  final int? advertisingRetryMaxMillis;

  /// Minimum delay in milliseconds between two outgoing connection attempts
  /// (default: 1000).
  final int? connectDelayMillis;

  /// Duration in seconds of the initial discovery phase (default: 30; 0 means
  /// never stop by time).
  final int? initialDiscoveryDurationSeconds;

  /// Duration in seconds of a standard (non-initial) discovery phase
  /// (default: 15; 0 means never stop by time).
  final int? discoveryDurationSeconds;

  /// Pause in seconds between two discovery phases (default: 45).
  final int? discoveryPauseSeconds;

  /// Random +/- jitter in seconds applied to the discovery pause (default: 15;
  /// must be <= pause). 0 disables jitter.
  final int? discoveryPauseJitterSeconds;

  /// Soft cap in KB for the total TX log payload batched into a single
  /// TxLogData message (default: 100).
  final int? txLogBatchSizeKb;

  /// Maximum number of TX logs to batch into a single TxLogData message
  /// (default: 1000). Must be in the range (0, 100000].
  final int? txLogBatchMaxCount;

  /// Maximum age in seconds of TX logs kept in the local mesh storage
  /// (default: 8 hours).
  final int? txLogMaxAgeSeconds;

  final List<int> _networkInternalHandles = [];

  MeshConfig._(this.meshId,
      {this.maxConnectionCount,
      this.backoffMillis,
      this.evictionBackoffMillis,
      this.randomSeed,
      this.requestTimeoutMillis,
      this.advertisingDelayMillis,
      this.advertisingRetryMillis,
      this.advertisingRetryMaxMillis,
      this.connectDelayMillis,
      this.initialDiscoveryDurationSeconds,
      this.discoveryDurationSeconds,
      this.discoveryPauseSeconds,
      this.discoveryPauseJitterSeconds,
      this.txLogBatchSizeKb,
      this.txLogBatchMaxCount,
      this.txLogMaxAgeSeconds});

  void _addNetworkInternalHandle(int networkInternalHandle) {
    _networkInternalHandles.add(networkInternalHandle);
  }

  /// Builds the native mesh options object from this configuration.
  ///
  /// The caller takes ownership of the returned pointer; it must either be
  /// passed to `sync_opt_mesh` (which frees it) or freed via `mesh_opt_free`.
  /// If building fails, the options are freed and the error is rethrown.
  Pointer<OBX_mesh_options> _build() {
    final opt = checkObxPtr(withNativeString(meshId, C.mesh_opt),
        'failed to create mesh options (mesh ID: "$meshId")');
    try {
      if (maxConnectionCount != null) {
        checkObx(C.mesh_opt_max_connection_count(opt, maxConnectionCount!));
      }
      if (backoffMillis != null) {
        checkObx(C.mesh_opt_backoff_millis(opt, backoffMillis!));
      }
      if (evictionBackoffMillis != null) {
        checkObx(
            C.mesh_opt_eviction_backoff_millis(opt, evictionBackoffMillis!));
      }
      if (randomSeed != null) {
        checkObx(C.mesh_opt_random_seed(opt, randomSeed!));
      }
      if (requestTimeoutMillis != null) {
        checkObx(C.mesh_opt_request_timeout_millis(opt, requestTimeoutMillis!));
      }
      if (advertisingDelayMillis != null) {
        checkObx(
            C.mesh_opt_advertising_delay_millis(opt, advertisingDelayMillis!));
      }
      if (advertisingRetryMillis != null) {
        checkObx(
            C.mesh_opt_advertising_retry_millis(opt, advertisingRetryMillis!));
      }
      if (advertisingRetryMaxMillis != null) {
        checkObx(C.mesh_opt_advertising_retry_max_millis(
            opt, advertisingRetryMaxMillis!));
      }
      if (connectDelayMillis != null) {
        checkObx(C.mesh_opt_connect_delay_millis(opt, connectDelayMillis!));
      }
      if (initialDiscoveryDurationSeconds != null) {
        checkObx(C.mesh_opt_initial_discovery_duration_seconds(
            opt, initialDiscoveryDurationSeconds!));
      }
      if (discoveryDurationSeconds != null) {
        checkObx(C.mesh_opt_discovery_duration_seconds(
            opt, discoveryDurationSeconds!));
      }
      if (discoveryPauseSeconds != null) {
        checkObx(
            C.mesh_opt_discovery_pause_seconds(opt, discoveryPauseSeconds!));
      }
      if (discoveryPauseJitterSeconds != null) {
        checkObx(C.mesh_opt_discovery_pause_jitter_seconds(
            opt, discoveryPauseJitterSeconds!));
      }
      if (txLogBatchSizeKb != null) {
        checkObx(C.mesh_opt_tx_log_batch_size_kb(opt, txLogBatchSizeKb!));
      }
      if (txLogBatchMaxCount != null) {
        checkObx(C.mesh_opt_tx_log_batch_max_count(opt, txLogBatchMaxCount!));
      }
      if (txLogMaxAgeSeconds != null) {
        checkObx(C.mesh_opt_tx_log_max_age_seconds(opt, txLogMaxAgeSeconds!));
      }
      for (final handle in _networkInternalHandles) {
        checkObx(C.mesh_opt_network_internal(
            opt, Pointer<Void>.fromAddress(handle)));
      }
    } catch (e) {
      // Free the options if any option method call failed (like due to invalid
      // arguments).
      C.mesh_opt_free(opt);
      rethrow;
    }
    return opt;
  }
}

/// Internal access for platform integrations and Sync client implementation.
class InternalSyncAccess {
  /// Creates a mesh sync configuration. See [MeshConfig] field documentation
  /// for details on each option.
  static MeshConfig createMeshConfig(String meshId,
          {int? maxConnectionCount,
          int? backoffMillis,
          int? evictionBackoffMillis,
          int? randomSeed,
          int? requestTimeoutMillis,
          int? advertisingDelayMillis,
          int? advertisingRetryMillis,
          int? advertisingRetryMaxMillis,
          int? connectDelayMillis,
          int? initialDiscoveryDurationSeconds,
          int? discoveryDurationSeconds,
          int? discoveryPauseSeconds,
          int? discoveryPauseJitterSeconds,
          int? txLogBatchSizeKb,
          int? txLogBatchMaxCount,
          int? txLogMaxAgeSeconds}) =>
      MeshConfig._(meshId,
          maxConnectionCount: maxConnectionCount,
          backoffMillis: backoffMillis,
          evictionBackoffMillis: evictionBackoffMillis,
          randomSeed: randomSeed,
          requestTimeoutMillis: requestTimeoutMillis,
          advertisingDelayMillis: advertisingDelayMillis,
          advertisingRetryMillis: advertisingRetryMillis,
          advertisingRetryMaxMillis: advertisingRetryMaxMillis,
          connectDelayMillis: connectDelayMillis,
          initialDiscoveryDurationSeconds: initialDiscoveryDurationSeconds,
          discoveryDurationSeconds: discoveryDurationSeconds,
          discoveryPauseSeconds: discoveryPauseSeconds,
          discoveryPauseJitterSeconds: discoveryPauseJitterSeconds,
          txLogBatchSizeKb: txLogBatchSizeKb,
          txLogBatchMaxCount: txLogBatchMaxCount,
          txLogMaxAgeSeconds: txLogMaxAgeSeconds);

  /// Adds a platform-specific native network to a mesh config.
  static void addNetworkInternalHandle(
          MeshConfig mesh, int networkInternalHandle) =>
      mesh._addNetworkInternalHandle(networkInternalHandle);

  /// Builds native mesh options for attaching [mesh] to a Sync client.
  static Pointer<OBX_mesh_options> buildMeshOptions(MeshConfig mesh) =>
      mesh._build();

  /// Wraps a native mesh owned by a Sync client.
  static MeshSync createMeshSync(Pointer<OBX_mesh> mesh) => MeshSync._(mesh);

  /// Invalidates a mesh wrapper after its owning Sync client closes.
  static void closeMeshSync(MeshSync? mesh) => mesh?._close();
}

/// A running peer-to-peer mesh sync, obtained from a Sync client's `mesh`
/// property.
///
/// Configure a mesh via [MeshConfig] passed to a Sync client constructor. The
/// mesh is owned by the sync client and starts and stops together with it.
class MeshSync {
  Pointer<OBX_mesh> _cMesh;

  MeshSync._(this._cMesh);

  /// The low-level pointer to the native mesh.
  ///
  /// The native mesh is owned by its Sync client; once the client is closed,
  /// this pointer is invalidated (see [_close]) and any access throws.
  @pragma('vm:prefer-inline')
  Pointer<OBX_mesh> get _ptr => (_cMesh.address != 0)
      ? _cMesh
      : throw StateError(
          'MeshSync already closed (the owning SyncClient was closed)');

  /// Invalidates this mesh. Called by the owning Sync client when it is closed.
  ///
  /// The native mesh is owned and freed by the sync client, so this only resets
  /// the (now dangling) pointer; any later access throws a [StateError].
  void _close() {
    _cMesh = nullptr;
  }

  /// Gets the current state of the mesh sync.
  MeshState state() {
    switch (C.mesh_state(_ptr)) {
      case OBXMeshState.Created:
        return MeshState.created;
      case OBXMeshState.Discovering:
        return MeshState.discovering;
      case OBXMeshState.FullyConnected:
        return MeshState.fullyConnected;
      case OBXMeshState.Stopped:
        return MeshState.stopped;
      case OBXMeshState.Dead:
        return MeshState.dead;
      default:
        return MeshState.unknown;
    }
  }

  /// Gets a human-readable string for the current mesh sync state (e.g.
  /// "Discovering").
  String stateString() => dartStringFromC(C.mesh_state_string(_ptr));

  /// Returns the number of currently connected peers.
  int connectedPeerCount() => C.mesh_connected_peer_count(_ptr);

  /// Gets a mesh sync statistics counter value, see [MeshStats].
  int stats(MeshStats counter) {
    final count = malloc<Uint64>();
    try {
      checkObx(C.mesh_stats_u64(_ptr, counter._id, count));
      return count.value;
    } finally {
      malloc.free(count);
    }
  }

  /// Requests an immediate retry of the network radios: advertising (bypassing
  /// the current retry backoff) and discovery (restarting the current phase).
  ///
  /// Call this when conditions that may have prevented the radios from
  /// starting have changed, e.g. the user just granted the required
  /// permissions. Thread-safe; the actual retry happens on the mesh sync
  /// thread shortly after.
  void retryNetworks() => checkObx(C.mesh_retry_networks(_ptr));
}
