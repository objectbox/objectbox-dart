part of 'store.dart';

/// Simple wrapper used below in ObservableStore to reduce code duplication.
/// Contains shared code for single-entity observer and the generic/global one.
class _Observer<StreamValueType> implements Finalizable {
  late final StreamController<StreamValueType> controller;
  Pointer<OBX_observer>? _cObserver;
  final receivePort = ReceivePort();

  /// Closes a native observer that is still open when its isolate shuts down
  /// (e.g. a Flutter engine is destroyed while a stream is subscribed) or if
  /// this is garbage collected without the subscription being canceled.
  ///
  /// Keeps the finalizer itself reachable (static), otherwise it might be
  /// disposed of before the finalizer callback gets a chance to run.
  static final _finalizer = NativeFinalizer(C.addresses.observer_close.cast());

  /// Ensures [_finalizer] exists. Call before the finalizer of Store is created:
  /// at isolate shutdown, native finalizers run in the order their finalizer
  /// objects were created, and observers must be closed before the store.
  static void initFinalizer() => _finalizer;

  int get nativePort => receivePort.sendPort.nativePort;

  set cObserver(Pointer<OBX_observer> value) {
    final cObserver = checkObxPtr(value, 'observer initialization failed');
    _cObserver = cObserver;
    _finalizer.attach(this, cObserver.cast(), detach: this);
    _debugLog('started');
  }

  Stream<StreamValueType> get stream => controller.stream;

  _Observer() {
    initializeDartAPI();
  }

  // start() is called whenever user starts listen()-ing to the stream
  void init(void Function() start,
      {bool broadcast = false, void Function()? onCancel}) {
    controller = broadcast
        ? StreamController<StreamValueType>.broadcast(
            onListen: start, onCancel: stop)
        : StreamController<StreamValueType>(
            onListen: start,
            onPause: stop,
            onResume: start,
            onCancel: () {
              stop();
              close();
              onCancel?.call();
            });
  }

  // stop() is called when the stream subscription is paused or canceled
  @pragma('vm:prefer-inline')
  void stop() {
    _debugLog('stopped');
    final cObserver = _cObserver;
    if (cObserver != null) {
      _finalizer.detach(this);
      // Mark as closed before the native call: even if it reports an error
      // the handle must not be used (or closed) again.
      _cObserver = null;
      checkObx(C.observer_close(cObserver));
    }
  }

  @pragma('vm:prefer-inline')
  void close() {
    _debugLog('closed');
    receivePort.close();
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
    if (_entityChanges != null) {
      return _entityChanges!
          .where((List<Type> entities) => entities.contains(EntityT))
          .map((_) {});
    }

    final observer = _Observer<void>();
    final entityId = _entityDef<EntityT>().model.id.id;

    // We're listening to events on single entity so there's no argument.
    // Ideally, controller.add() would work but it doesn't, even though we're
    // using StreamController<Void> so the argument type is `void`.
    observer.receivePort.listen((dynamic _) => observer.controller.add(null));

    observer.init(() {
      observer.cObserver = C.dartc_observe_single_type(
          _cStoreChecked, entityId, observer.nativePort);
    }, onCancel: () => _onClose.remove(observer));

    // Close the native observer before the native store is closed (it is
    // freed with the store; closing it on a later cancel would then be a
    // use-after-free) and the port so it does not keep the isolate alive.
    _onClose[observer] = () {
      observer.stop();
      observer.close();
    };

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

    // We're listening to a events for all entity types. C-API sends entity ID
    // and we must map it to a dart type (class) corresponding to that entity.
    observer.receivePort.listen((dynamic entityIds) {
      if (entityIds is! Uint32List) {
        observer.controller.addError(ObjectBoxException(
            'Received invalid data format from the core notification: (${entityIds.runtimeType}) $entityIds'));
        return;
      }

      final entities = List<Type>.filled(entityIds.length, Null);
      for (var i = 0; i < entityIds.length; i++) {
        final entityId = entityIds[i];
        final entityType = entityTypesById[entityId];
        if (entityType == null) {
          observer.controller.addError(ObjectBoxException(
              'Received data change notification for an unknown entity ID $entityId'));
          // Do not also emit an event with placeholder (Null) types.
          return;
        } else {
          entities[i] = entityType;
        }
      }
      observer.controller.add(entities);
    });

    observer.init(() {
      observer.cObserver = C.dartc_observe(_cStoreChecked, observer.nativePort);
    }, broadcast: broadcast);

    if (broadcast) {
      // Close the native observer before the native store is closed (it is
      // freed with the store; closing it on a later cancel would then be a
      // use-after-free) and the port so it does not keep the isolate alive.
      _onClose[observer] = () {
        observer.stop();
        observer.close();
      };
    }

    return observer.stream;
  }

  /// Returns a broadcast stream to data changes on all Entity types.
  ///
  /// The stream receives an event whenever any data changes in the database.
  /// Make sure to cancel() the subscription after you're done with it to avoid
  /// hanging change listeners.
  Stream<List<Type>> get entityChanges =>
      _entityChanges ??= _watchAll(broadcast: true);
}
