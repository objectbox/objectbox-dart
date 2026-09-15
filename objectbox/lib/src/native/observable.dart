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

  /// Creates the stream [controller].
  ///
  /// Callers need to make sure [finalize] is called if the store is about to
  /// close, such as by adding a callback to [Store._onClose].
  ///
  /// [createNativeObserver] should create and set [cObserver]. It is called
  /// whenever a stream is listen()-ed to or resumed.
  ///
  /// [onCancel] is run when a non-broadcast stream is cancelled, in addition to
  /// [finalize].
  void init(void Function() createNativeObserver,
      {bool broadcast = false, void Function()? onCancel}) {
    controller = broadcast
        ? StreamController<StreamValueType>.broadcast(
            onListen: createNativeObserver, onCancel: closeNativeObserver)
        : StreamController<StreamValueType>(
            onListen: createNativeObserver,
            onPause: closeNativeObserver,
            onResume: createNativeObserver,
            onCancel: () {
              finalize();
              onCancel?.call();
            });
  }

  /// Closes the native observer, leaving the [receivePort] open to allow to
  /// re-use it (by setting a new [cObserver]).
  ///
  /// Call this when the stream subscription is paused or canceled.
  @pragma('vm:prefer-inline')
  void closeNativeObserver() {
    _debugLog('closed');
    final cObserver = _cObserver;
    if (cObserver != null) {
      _finalizer.detach(this);
      // Mark as closed before the native call: even if it reports an error
      // the handle must not be used (or closed) again.
      _cObserver = null;
      checkObx(C.observer_close(cObserver));
    }
  }

  /// Cleans up all associated resources by calling [closeNativeObserver] and
  /// closing the [receivePort]. This can't be used afterward.
  ///
  /// Call if this observer shouldn't be used again, like when the stream is
  /// cancelled.
  @pragma('vm:prefer-inline')
  void finalize() {
    closeNativeObserver();
    _debugLog('finished');
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
    // Remove the callback if the subscription to the stream is cancelled
    // (see onCancel callback above) as _Observer already cleaned itself up.
    _onClose[observer] = observer.finalize;

    return observer.stream;
  }

  /// Create a broadcast stream to data changes on all Entity types.
  ///
  /// The stream receives an event whenever any data changes in the database.
  /// Make sure to cancel() the subscription after you're done with it to avoid
  /// hanging change listeners.
  Stream<List<Type>> _watchAll() {
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
    }, broadcast: true);

    // Close the native observer before the native store is closed (it is
    // freed with the store; closing it on a later cancel would then be a
    // use-after-free) and the port so it does not keep the isolate alive.
    // As the broadcast stream can be re-used (it is cached in entityChanges)
    // don't remove the _onClose callback if a subscriber cancels its
    // subscription.
    _onClose[observer] = observer.finalize;

    return observer.stream;
  }

  /// Returns a broadcast stream to data changes on all Entity types.
  ///
  /// The stream receives an event whenever any data changes in the database.
  /// Make sure to cancel() the subscription after you're done with it to avoid
  /// hanging change listeners.
  Stream<List<Type>> get entityChanges => _entityChanges ??= _watchAll();
}
