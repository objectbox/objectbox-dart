import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'bindings/bindings.dart';
import 'bindings/helpers.dart';
import 'store.dart';

/// Simple wrapper used below in ObservableStore to reduce code duplication.
/// Contains shared code for single-entity observer and the generic/global one.
class _Observer<StreamValueType> {
  late final StreamController<StreamValueType> controller;
  Pointer<OBX_observer>? _cObserver;
  ReceivePort? receivePort;

  int get nativePort => receivePort!.sendPort.nativePort;

  set cObserver(Pointer<OBX_observer> value) {
    _cObserver = checkObxPtr(value, 'observer initialization failed');
    _debugLog('started');
  }

  Stream<StreamValueType> get stream => controller.stream;

  _Observer() {
    initializeDartAPI();
  }

  // start() is called whenever user starts listen()-ing to the stream
  void init(void Function() start, {bool broadcast = false}) {
    controller = broadcast
        ? StreamController<StreamValueType>.broadcast(
            onListen: start, onCancel: stop)
        : StreamController<StreamValueType>(
            onListen: start, onPause: stop, onResume: start, onCancel: stop);
  }

  // stop() is called when the stream subscription is paused or canceled
  void stop() {
    _debugLog('stopped');
    if (_cObserver != null) {
      checkObx(C.observer_close(_cObserver!));
      _cObserver = null;
    }

    if (receivePort != null) {
      receivePort!.close();
      receivePort = null;
    }
  }

  @pragma('vm:prefer-inline')
  void _debugLog(String message) {
    // print('Observer=${_cObserver?.address} $message');
  }
}

/// StreamController implementation inspired by the sample controller sample at:
/// https://dart.dev/articles/libraries/creating-streams#honoring-the-pause-state
/// https://dart.dev/articles/libraries/code/stream_controller.dart
extension ObservableStore on Store {
  /// Create a stream to data changes on EntityT (stored Entity class).
  ///
  /// The stream receives an event whenever an object of EntityT is created or
  /// changed or deleted. Make sure to cancel() the subscription after you're
  /// done with it to avoid hanging change listeners.
  Stream<void> watch<EntityT>() {
    final observer = _Observer<void>();
    final entityId = InternalStoreAccess.entityDef<EntityT>(this).model.id.id;

    observer.init(() {
      // We're listening to events on single entity so there's no argument.
      // Ideally, controller.add() would work but it doesn't, even though we're
      // using StreamController<Void> so the argument type is `void`.
      observer.receivePort = ReceivePort()
        ..listen((dynamic _) => observer.controller.add(null));
      observer.cObserver = C.dartc_observe_single_type(
          InternalStoreAccess.ptr(this), entityId, observer.nativePort);
    });

    return observer.stream;
  }

  /// Create a stream (normal or broadcast) to data changes on all Entity types.
  ///
  /// The stream receives an event whenever any data changes in the database.
  /// Make sure to cancel() the subscription after you're done with it to avoid
  /// hanging change listeners.
  Stream<List<Type>> _watchAll({bool broadcast = false}) {
    initializeDartAPI();
    final observer = _Observer<List<Type>>();
    final entityTypesById = InternalStoreAccess.entityTypeById(this);

    final start = () {
      // We're listening to a events for all entity types. C-API sends entity ID
      // and we must map it to a dart type (class) corresponding to that entity.
      observer.receivePort = ReceivePort()
        ..listen((dynamic entityIds) {
          if (entityIds is! Uint32List) {
            observer.controller.addError(Exception(
                'Received invalid data format from the core notification: (${entityIds.runtimeType}) $entityIds'));
            return;
          }

          final entities = List<Type>.filled(entityIds.length, Null);
          for (var i = 0; i < entityIds.length; i++) {
            final entityId = entityIds[i];
            if (entityId is! int) {
              observer.controller.addError(Exception(
                  'Received invalid item data format from the core notification: (${entityId.runtimeType}) $entityId'));
              return;
            }

            final entityType = entityTypesById[entityId];
            if (entityType == null) {
              observer.controller.addError(Exception(
                  'Received data change notification for an unknown entity ID $entityId'));
            } else {
              entities[i] = entityType;
            }
          }
          observer.controller.add(entities);
        });
      observer.cObserver =
          C.dartc_observe(InternalStoreAccess.ptr(this), observer.nativePort);
    };

    observer.init(start, broadcast: broadcast);

    return observer.stream;
  }

  /// Returns a broadcast stream to data changes on all Entity types.
  ///
  /// The stream receives an event whenever any data changes in the database.
  /// Make sure to cancel() the subscription after you're done with it to avoid
  /// hanging change listeners.
  Stream<List<Type>> get entityChanges {
    final stream = _singletonChangesStream[this];
    if (stream != null) return stream;
    return _singletonChangesStream[this] = _watchAll(broadcast: true);
  }
}

final _singletonChangesStream = HashMap<Store, Stream<List<Type>>>();
