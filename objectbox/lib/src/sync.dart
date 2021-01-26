import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import 'bindings/bindings.dart';
import 'bindings/helpers.dart';
import 'bindings/structs.dart';
import 'store.dart';
import 'util.dart';

/// Credentials used to authenticate a sync client against a server.
class SyncCredentials {
  final int _type;
  final Uint8List _data;

  SyncCredentials._(this._type, String data)
      : _data = Uint8List.fromList(utf8.encode(data));

  /// No credentials - usually only for development purposes with a server
  /// configured to accept all connections without authentication.
  SyncCredentials.none()
      : _type = OBXSyncCredentialsType.NONE,
        _data = Uint8List(0);

  /// Shared secret authentication.
  SyncCredentials.sharedSecretUint8List(this._data)
      : _type = OBXSyncCredentialsType.SHARED_SECRET;

  /// Shared secret authentication.
  SyncCredentials.sharedSecretString(String data)
      : this._(OBXSyncCredentialsType.SHARED_SECRET, data);

  /// Google authentication.
  SyncCredentials.googleAuthUint8List(this._data)
      : _type = OBXSyncCredentialsType.GOOGLE_AUTH;

  /// Google authentication.
  SyncCredentials.googleAuthString(String data)
      : this._(OBXSyncCredentialsType.GOOGLE_AUTH, data);
}

/// Current state of the [SyncClient].
enum SyncState {
  /// State is unknown, e.g. C-API reported a state that's not recognized yet.
  unknown,

  /// Client created but not yet started.
  created,

  /// Client started and connecting.
  started,

  /// Connection with the server established but not authenticated yet.
  connected,

  /// Client authenticated and synchronizing.
  loggedIn,

  /// Lost connection, will try to reconnect if the credentials are valid.
  disconnected,

  /// Client in the process of being closed.
  stopped,

  /// Invalid access to the client after it was closed.
  dead
}

/// Configuration of how [SyncClient] fetches remote updates from the server.
enum SyncRequestUpdatesMode {
  /// No updates, [SyncClient.requestUpdates()] must be called manually.
  manual,

  /// Automatic updates, including subsequent pushes from the server, same as
  /// calling [SyncClient.requestUpdates(true)]. This is the default unless
  /// changed by [SyncClient.setRequestUpdatesMode()].
  auto,

  /// Automatic update after connection, without subscribing for pushes from the
  /// server. Similar to calling [SyncClient.requestUpdates(false)].
  autoNoPushes
}

/// Connection state change event.
enum SyncConnectionEvent { connected, disconnected }

/// Login state change event.
enum SyncLoginEvent { loggedIn, credentialsRejected, unknownError }

/// Sync incoming data event.
class SyncChange {
  final int entityId;
  final Type entity;
  final List<int> puts;
  final List<int> removals;

  SyncChange(this.entityId, this.entity, this.puts, this.removals);
}

/// Sync client is used to connect to an ObjectBox sync server.
class SyncClient {
  final Store _store;

  /*late final*/
  Pointer<OBX_sync> _cSync;

  /// The low-level pointer to this box.
  Pointer<OBX_sync> get ptr => (_cSync.address != 0)
      ? _cSync
      : throw Exception('SyncClient already closed');

  /// Creates a sync client associated with the given store and options.
  /// This does not initiate any connection attempts yet: call start() to do so.
  SyncClient(this._store, String serverUri, SyncCredentials creds) {
    if (!Sync.isAvailable()) {
      throw Exception(
          'Sync is not available in the loaded ObjectBox runtime library. '
          'Please visit https://objectbox.io/sync/ for options.');
    }

    final cServerUri = Utf8.toUtf8(serverUri).cast<Int8>();
    try {
      _cSync = checkObxPtr(
          C.sync_1(_store.ptr, cServerUri), 'failed to create sync client');
    } finally {
      free(cServerUri);
    }

    setCredentials(creds);
  }

  /// Closes and cleans up all resources used by this sync client.
  /// It can no longer be used afterwards, make a new sync client instead.
  /// Does nothing if this sync client has already been closed.
  void close() {
    _connectionEvents?._stop();
    _loginEvents?._stop();
    _completionEvents?._stop();
    _changeEvents?._stop();
    final err = C.sync_close(_cSync);
    _cSync = nullptr;
    syncClientsStorage.remove(_store);
    InternalStoreAccess.removeCloseListener(_store, this);
    checkObx(err);
  }

  /// Returns if this sync client is closed and can no longer be used.
  bool isClosed() => _cSync.address == 0;

  /// Gets the current sync client state.
  SyncState state() {
    final state = C.sync_state(ptr);
    switch (state) {
      case OBXSyncState.CREATED:
        return SyncState.created;
      case OBXSyncState.STARTED:
        return SyncState.started;
      case OBXSyncState.CONNECTED:
        return SyncState.connected;
      case OBXSyncState.LOGGED_IN:
        return SyncState.loggedIn;
      case OBXSyncState.DISCONNECTED:
        return SyncState.disconnected;
      case OBXSyncState.STOPPED:
        return SyncState.stopped;
      case OBXSyncState.DEAD:
        return SyncState.dead;
      default:
        return SyncState.unknown;
    }
  }

  /// Configure authentication credentials, depending on your server config.
  void setCredentials(SyncCredentials creds) {
    final cCreds = OBX_bytes_wrapper.managedCopyOf(creds._data, align: false);
    try {
      checkObx(C.sync_credentials(
          ptr,
          creds._type,
          creds._type == OBXSyncCredentialsType.NONE ? nullptr : cCreds.ptr,
          cCreds.size));
    } finally {
      cCreds.freeManaged();
    }
  }

  /// Configures how sync updates are received from the server. If automatic
  /// updates are turned off, they will need to be requested manually.
  void setRequestUpdatesMode(SyncRequestUpdatesMode mode) {
    int cMode;
    switch (mode) {
      case SyncRequestUpdatesMode.manual:
        cMode = OBXRequestUpdatesMode.MANUAL;
        break;
      case SyncRequestUpdatesMode.auto:
        cMode = OBXRequestUpdatesMode.AUTO;
        break;
      case SyncRequestUpdatesMode.autoNoPushes:
        cMode = OBXRequestUpdatesMode.AUTO_NO_PUSHES;
        break;
      default:
        throw Exception('Unknown mode argument: ' + mode.toString());
    }
    checkObx(C.sync_request_updates_mode(ptr, cMode));
  }

  /// Once the sync client is configured, you can [start] it to initiate
  /// synchronization.
  ///
  /// This method triggers communication in the background and returns
  /// immediately. The background thread will try to connect to the server,
  /// log-in and start syncing data (depends on [SyncRequestUpdatesMode]).
  /// If the device, network or server is currently offline, connection attempts
  /// will be retried later automatically. If you haven't set the credentials in
  /// the options during construction, call [setCredentials()] before [start()].
  void start() {
    checkObx(C.sync_start(ptr));
  }

  /// Stops this sync client. Does nothing if it is already stopped.
  void stop() {
    checkObx(C.sync_stop(ptr));
  }

  /// Request updates since we last synchronized our database.
  ///
  /// Additionally, you can subscribe for future pushes from the server, to let
  /// it send us future updates as they come in.
  /// Call [cancelUpdates()] to stop the updates.
  bool requestUpdates({/*required*/ bool subscribeForFuturePushes}) =>
      checkObxSuccess(C.sync_updates_request(ptr, subscribeForFuturePushes));

  /// Cancel updates from the server so that it will stop sending updates.
  /// See also [requestUpdates()].
  bool cancelUpdates() => checkObxSuccess(C.sync_updates_cancel(ptr));

  /// Count the number of messages in the outgoing queue, i.e. those waiting to
  /// be sent to the server.
  ///
  /// Note: This calls uses a (read) transaction internally:
  ///   1) It's not just a "cheap" return of a single number. While this will
  ///      still be fast, avoid calling this function excessively.
  ///   2) the result follows transaction view semantics, thus it may not always
  ///      match the actual value.
  int outgoingMessageCount({int limit = 0}) {
    final count = allocate<Uint64>();
    try {
      checkObx(C.sync_outgoing_message_count(ptr, limit, count));
      return count.value;
    } finally {
      free(count);
    }
  }

  _SyncListenerGroup<SyncConnectionEvent> /*?*/ _connectionEvents;

  /// Get a broadcast stream of connection state changes (connect/disconnect).
  ///
  /// Subscribe (listen) to the stream to actually start listening to events.
  Stream<SyncConnectionEvent> get connectionEvents {
    if (_connectionEvents == null) {
      // Combine events from two C listeners: connect & disconnect.
      _connectionEvents =
          _SyncListenerGroup<SyncConnectionEvent>('sync-connection');

      _connectionEvents.add(_SyncListenerConfig(
          (int nativePort) => C.dartc_sync_listener_connect(ptr, nativePort),
          (_, controller) => controller.add(SyncConnectionEvent.connected)));

      _connectionEvents.add(_SyncListenerConfig(
          (int nativePort) => C.dartc_sync_listener_disconnect(ptr, nativePort),
          (_, controller) => controller.add(SyncConnectionEvent.disconnected)));

      _connectionEvents.finish();
    }
    return _connectionEvents.stream;
  }

  _SyncListenerGroup<SyncLoginEvent> /*?*/ _loginEvents;

  /// Get a broadcast stream of login events (success/failure).
  ///
  /// Subscribe (listen) to the stream to actually start listening to events.
  Stream<SyncLoginEvent> get loginEvents {
    if (_loginEvents == null) {
      // Combine events from two C listeners: login & login-failure.
      _loginEvents = _SyncListenerGroup<SyncLoginEvent>('sync-login');

      _loginEvents.add(_SyncListenerConfig(
          (int nativePort) => C.dartc_sync_listener_login(ptr, nativePort),
          (_, controller) => controller.add(SyncLoginEvent.loggedIn)));

      _loginEvents.add(_SyncListenerConfig(
          (int nativePort) =>
              C.dartc_sync_listener_login_failure(ptr, nativePort),
          (code, controller) {
        // see OBXSyncCode - TODO should we match any other codes?
        switch (code) {
          case OBXSyncCode.CREDENTIALS_REJECTED:
            return controller.add(SyncLoginEvent.credentialsRejected);
          default:
            return controller.add(SyncLoginEvent.unknownError);
        }
      }));

      _loginEvents.finish();
    }
    return _loginEvents.stream;
  }

  _SyncListenerGroup<void> /*?*/ _completionEvents;

  /// Get a broadcast stream of sync completion events - when synchronization
  /// of incoming changes has completed.
  ///
  /// Subscribe (listen) to the stream to actually start listening to events.
  Stream<void> get completionEvents {
    if (_completionEvents == null) {
      _completionEvents = _SyncListenerGroup<void>('sync-completion');

      _completionEvents.add(_SyncListenerConfig(
          (int nativePort) => C.dartc_sync_listener_complete(ptr, nativePort),
          (_, controller) => controller.add(null)));

      _completionEvents.finish();
    }
    return _completionEvents.stream;
  }

  _SyncListenerGroup<List<SyncChange>> /*?*/ _changeEvents;

  /// Get a broadcast stream of incoming synced data changes.
  ///
  /// Subscribe (listen) to the stream to actually start listening to events.
  Stream<List<SyncChange>> get changeEvents {
    if (_changeEvents == null) {
      // This stream combines events from two C listeners: connect & disconnect.
      _changeEvents = _SyncListenerGroup<List<SyncChange>>('sync-change');

      // create a map from Entity ID to Entity type (dart class)
      final entityTypesById = <int, Type>{};
      InternalStoreAccess.defs(_store).bindings.forEach(
          (Type entity, EntityDefinition entityDef) =>
              entityTypesById[entityDef.model.id.id] = entity);

      _changeEvents.add(_SyncListenerConfig(
          (int nativePort) => C.dartc_sync_listener_change(ptr, nativePort),
          (syncChanges, controller) {
        if (syncChanges is! List) {
          controller.addError(Exception(
              'Received invalid data type from the core notification: (${syncChanges.runtimeType}) $syncChanges'));
          return;
        }

        // List<SyncChange> is flattened to List<dynamic>, with SyncChange object
        // properties always coming in groups of three (entityId, puts, removals)
        const numProperties = 3;
        if (syncChanges.length % numProperties != 0) {
          controller.addError(Exception(
              'Received invalid list length from the core notification: (${syncChanges.runtimeType}) $syncChanges'));
          return;
        }

        final changes = <SyncChange>[];
        for (var i = 0; i < syncChanges.length / numProperties; i++) {
          final entityId = syncChanges[i * numProperties + 0];
          final putsBytes = syncChanges[i * numProperties + 1];
          final removalsBytes = syncChanges[i * numProperties + 2];

          final entityType = entityTypesById[entityId];
          if (entityType == null) {
            controller.addError(Exception(
                'Received sync change notification for an unknown entity ID $entityId'));
            return;
          }

          if (entityId is! int ||
              putsBytes is! Uint8List ||
              removalsBytes is! Uint8List) {
            controller.addError(Exception(
                'Received invalid list items format from the core notification at i=${i}: '
                'entityId = (${entityId.runtimeType}) $entityId; '
                'putsBytes = (${putsBytes.runtimeType}) $putsBytes; '
                'removalsBytes = (${removalsBytes.runtimeType}) $removalsBytes'));
            return;
          }

          changes.add(SyncChange(
              entityId,
              entityType,
              Uint64List.view(putsBytes.buffer).toList(),
              Uint64List.view(removalsBytes.buffer).toList()));
        }

        controller.add(changes);
      }));

      _changeEvents.finish();
    }
    return _changeEvents.stream;
  }
}

/// Configuration for _SyncListenerGroup, setting up a single native listener.
class _SyncListenerConfig {
  /// Function to create a new native listener.
  final Pointer<OBX_dart_sync_listener> Function(int nativePort) cListenerInit;

  /// Called on message from a native listener.
  final void Function(dynamic msg, StreamController controller) dartListener;

  _SyncListenerConfig(this.cListenerInit, this.dartListener);
}

/// Wrapper used in SyncClient for event listeners forwarding.
/// Supports merging events from multiple native listeners to a single stream.
class _SyncListenerGroup<StreamValueType> {
  final String name;
  bool finished = false;

  /*late final*/
  StreamController<StreamValueType> controller;
  final _configs = <_SyncListenerConfig>[];

  // currently active native listeners and ports attached to them
  final _cListeners = <Pointer<OBX_dart_sync_listener>>[];
  final _receivePorts = <ReceivePort>[];

  Stream<StreamValueType> get stream {
    assert(finished, 'Call finish() before accessing .stream');
    return controller.stream;
  }

  /// start() is called whenever user starts listen()-ing to the stream
  _SyncListenerGroup(this.name) {
    initializeDartAPI();
  }

  /// Add a native->dart forwarder config to the group.
  void add(_SyncListenerConfig config) {
    assert(!finished, "Can't add more listeners after calling finish().");
    _configs.add(config);
  }

  /// Finish the group, creating a listener.
  Stream<StreamValueType> finish() {
    assert(!finished, 'finish() may only be called once.');
    controller = StreamController<StreamValueType>.broadcast(
        onListen: _start,
        /* not for broadcast streams: onPause: _stop, onResume: _start,*/
        onCancel: _stop);
    finished = true;
    return controller.stream;
  }

  // stop() is called when the stream subscription is started or resumed
  void _start() {
    _debugLog('starting');
    assert(finished, 'Starting an unfinished group?!');

    var hasError = false;
    _configs.forEach((_SyncListenerConfig config) {
      if (hasError) return;

      // Initialize a receive port where the native listener will post messages.
      final receivePort = ReceivePort()
        ..listen((msg) => config.dartListener(msg, controller));

      // Store the ReceivePort to be able to close it in _stop().
      _receivePorts.add(receivePort);

      // Start the native listener.
      final cListener = config.cListenerInit(receivePort.sendPort.nativePort);
      if (cListener == null || cListener == nullptr) {
        hasError = true;
      } else {
        _cListeners.add(cListener);
      }
    });

    if (hasError) {
      try {
        throw latestNativeError(
            dartMsg: 'Failed to initialize a sync native listener');
      } finally {
        _stop();
      }
    }

    _debugLog('started');
  }

  // stop() is called when the stream subscription is paused or canceled
  void _stop() {
    _debugLog('stopping');
    assert(finished, 'Stopping an unfinished group?!');

    final cErrorCodes = _cListeners
        .map(C.dartc_sync_listener_close) // map() is lazy
        .toList(growable: false); // call toList() to execute immediately
    _cListeners.clear();

    _receivePorts.forEach((rp) => rp.close());
    _receivePorts.clear();

    // throw on native, if any
    cErrorCodes.forEach(checkObx);

    _debugLog('stopped');
  }

  void _debugLog(String message) {
    // print('Listener ${name}: $message');
  }
}

/// [ObjectBox Sync](https://objectbox.io/sync/) makes data available and
/// synchronized across devices, online and offline.
///
/// Start a client using [Sync.client()] and connect to a remote server.
class Sync {
  /// Create a Sync annotation, enabling synchronization for an entity.
  const Sync();

  static /*late final*/ bool _syncAvailable;

  /// Returns true if the loaded ObjectBox native library supports Sync.
  static bool isAvailable() {
    // TODO remove try-catch after upgrading to objectbox-c v0.11 where obx_sync_available() exists.
    try {
      _syncAvailable ??= C.sync_available();
    } catch (_) {
      _syncAvailable = false;
    }
    return _syncAvailable;
  }

  /// Creates a sync client associated with the given store and configures it
  /// with the given options. This does not initiate any connection attempts
  /// yet, call [SyncClient.start()] to do so.
  ///
  /// Before [SyncClient.start()], you can still configure some aspects of the
  /// client, e.g. its [SyncRequestUpdatesMode] mode.
  static SyncClient client(
      Store store, String serverUri, SyncCredentials creds) {
    if (syncClientsStorage.containsKey(store)) {
      throw Exception('Only one sync client can be active for a store');
    }
    final client = SyncClient(store, serverUri, creds);
    syncClientsStorage[store] = client;
    InternalStoreAccess.addCloseListener(store, client, client.close);
    return client;
  }
}

/// Tests only.
// TODO enable annotation once meta:1.3.0 is out
// @internal
@visibleForTesting
class InternaSyncTestAccess {
  /// Access credentials internal data representation.
  static Uint8List credentialsData(SyncCredentials creds) => creds._data;
}
