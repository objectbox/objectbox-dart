part of 'store.dart';

/// Simple wrapper used below in ObservableStore to reduce code duplication.
/// Contains shared code for single-entity observer and the generic/global one.
class _Observer<StreamValueType> implements Finalizable {
  late final StreamController<StreamValueType> controller;
  Pointer<OBX_observer>? _cObserver;

  /// Created and kept open while the [stream] has listeners.
  ///
  /// This should be closed as soon as no longer needed, so it does not prevent
  /// the isolate from exiting.
  ReceivePort? _receivePort;

  /// The handler to attach to [_receivePort] whenever it is (re-)created.
  late final void Function(dynamic) _onData;

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

  Stream<StreamValueType> get stream => controller.stream;

  _Observer() {
    initializeDartAPI();
  }

  /// Creates the single-subscription or [broadcast] stream [controller].
  ///
  /// Callers need to make sure [close] is called if the store is about to
  /// close, such as by adding a callback to [Store._onClose].
  ///
  /// [createNativeObserver] should create a [cObserver], using the
  /// given native port to send change notifications to. It is called whenever
  /// the stream is listened to or resumed. This closes the [cObserver] on its
  /// own when the stream is paused or canceled.
  ///
  /// [onData] should handle messages received on the created receive port. If
  /// this creates a broadcast stream, it is re-attached to a new receive port
  /// each time the stream obtains at least one subscriber.
  ///
  /// [onCancel] is run when a non-broadcast stream is cancelled, in addition to
  /// [close].
  void init(
      {required Pointer<OBX_observer> Function(int nativePort)
          createNativeObserver,
      required void Function(dynamic) onData,
      void Function()? onCancel,
      bool broadcast = false}) {
    _onData = onData;

    void start() {
      // For non-broadcast streams, re-uses the port when resuming
      final receivePort = _receivePort ??= ReceivePort()..listen(_onData);
      final Pointer<OBX_observer> cObserver;
      try {
        cObserver = checkObxPtr(
            createNativeObserver(receivePort.sendPort.nativePort),
            'observer initialization failed');
      } catch (e, s) {
        controller.addError(e, s);
        close(); // closes the receive port; native observer was never created
        return;
      }
      _cObserver = cObserver;
      _finalizer.attach(this, cObserver.cast(), detach: this);
      _debugLog('started');
    }

    controller = broadcast
        ? StreamController<StreamValueType>.broadcast(
            onListen: start,
            // Once the last subscriber cancels, close the native observer and
            // the receive port so it does not keep the isolate alive. If the
            // stream is listened to again, start() above recreates both.
            onCancel: close)
        : StreamController<StreamValueType>(
            onListen: start,
            onPause: _closeNativeObserver,
            // The port is still open while paused, so start() reuses it as-is.
            onResume: start,
            onCancel: () {
              close();
              onCancel?.call();
            });
  }

  /// Closes the native observer, leaving the [_receivePort] open to allow to
  /// re-use it.
  ///
  /// This is useful when the stream is just paused as it avoids expensive
  /// creation of a new receive port.
  void _closeNativeObserver() {
    final cObserver = _cObserver;
    if (cObserver != null) {
      _finalizer.detach(this);
      // Mark as closed before the native call: even if it reports an error
      // the handle must not be used (or closed) again.
      _cObserver = null;
      checkObx(C.observer_close(cObserver));
      _debugLog('closed native observer');
    }
  }

  /// Cleans up all associated resources by calling [_closeNativeObserver] and
  /// closing the [_receivePort] so it does not keep the isolate alive.
  ///
  /// Safe to call multiple times.
  ///
  /// Call if the stream is cancelled.
  void close() {
    try {
      _closeNativeObserver();
    } finally {
      _receivePort?.close();
      _receivePort = null;
      _debugLog('closed port');
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
  /// Creates a single-subscription stream to data changes of a Box of an
  /// entity.
  ///
  /// The stream receives an event whenever an object of EntityT is created or
  /// changed or deleted. Make sure cancel() is called on the subscription after
  /// being done with it or close the store to clean up resources that prevent
  /// the isolate from exiting.
  Stream<void> watch<EntityT>() {
    final observer = _Observer<void>();
    final entityId = _entityDef<EntityT>().model.id.id;

    observer.init(
        createNativeObserver: (nativePort) =>
            C.dartc_observe_single_type(_cStoreChecked, entityId, nativePort),
        // We're listening to events on single entity so there's no argument.
        // Ideally, controller.add() would work but it doesn't, even though
        // we're using StreamController<Void> so the argument type is `void`.
        onData: (dynamic _) => observer.controller.add(null),
        onCancel: () => _onClose.remove(observer));

    // Close the native observer before the native store is closed (it is
    // freed with the store; closing it on a later cancel would then be a
    // use-after-free) and the port so it does not keep the isolate alive.
    // Remove the callback if the subscription to the stream is cancelled
    // (see onCancel callback above) as _Observer already cleaned itself up.
    _onClose[observer] = observer.close;

    return observer.stream;
  }

  /// Creates a broadcast stream to data changes on all Entity types.
  ///
  /// The stream receives an event whenever any data changes in the database.
  /// Make sure to cancel() the subscription after you're done with it to avoid
  /// hanging change listeners.
  Stream<List<Type>> _watchAll() {
    initializeDartAPI();
    final observer = _Observer<List<Type>>();
    final entityTypesById = InternalStoreAccess.entityTypeById(this);

    observer.init(
        createNativeObserver: (nativePort) =>
            C.dartc_observe(_cStoreChecked, nativePort),
        // We're listening to a events for all entity types. C-API sends
        // entity ID and we must map it to a dart type (class) corresponding
        // to that entity.
        onData: (dynamic entityIds) {
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
        },
        broadcast: true);

    // Close the native observer before the native store is closed (it is
    // freed with the store; closing it on a later cancel would then be a
    // use-after-free) and the port so it does not keep the isolate alive.
    // As the broadcast stream can be re-used (it is cached in entityChanges)
    // don't remove the _onClose callback if a subscriber cancels its
    // subscription.
    _onClose[observer] = observer.close;

    return observer.stream;
  }

  /// Returns a broadcast stream to data changes on all Entity types.
  ///
  /// The stream receives an event whenever any data changes in the database.
  /// Make sure to cancel() the subscription after you're done with it to avoid
  /// hanging change listeners.
  Stream<List<Type>> get entityChanges => _entityChanges ??= _watchAll();
}
