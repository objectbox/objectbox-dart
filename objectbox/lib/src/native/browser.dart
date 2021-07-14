import 'dart:ffi';

import 'bindings/bindings.dart';
import 'bindings/helpers.dart';
import 'store.dart';

/// Data browser allows you to explore the DB contents in a regular web browser.
///
/// The Browser runs directly on your device or on your development machine.
/// Behind the scenes this works by bundling a simple HTTP browser into
/// ObjectBox when building your app. If triggered, it will then provide a basic
/// web interface to the data and schema.
class Browser {
  late Pointer<OBX_browser> _cBrowser;
  late final Pointer<OBX_dart_finalizer> _cFinalizer;

  @pragma('vm:prefer-inline')
  Pointer<OBX_browser> get _ptr => (_cBrowser.address != 0)
      ? _cBrowser
      : throw StateError('Browser already closed');

  /// Whether the loaded ObjectBox native library supports ObjectBrowser.
  static bool isAvailable() => C.has_feature(OBXFeature.ObjectBrowser);

  /// Creates a sync client associated with the given store and options.
  /// This does not initiate any connection attempts yet: call start() to do so.
  Browser(Store store, {String bindUri = 'http://127.0.0.1:8090'}) {
    if (!isAvailable()) {
      throw UnsupportedError(
          'ObjectBrowser is not available in the loaded ObjectBox runtime library.');
    }
    initializeDartAPI();

    final opt = checkObxPtr(C.browser_opt());
    try {
      checkObx(
          C.browser_opt_store(opt, InternalStoreAccess.ptr(store), nullptr));
      checkObx(C.browser_opt_user_management(opt, false));
      withNativeString(bindUri,
          (Pointer<Int8> cStr) => checkObx(C.browser_opt_bind(opt, cStr)));
    } catch (_) {
      C.browser_opt_free(opt);
      rethrow;
    }

    _cBrowser = C.browser(opt);

    // Keep the finalizer so we can detach it when close() is called manually.
    _cFinalizer = C.dartc_attach_finalizer(
        this, native_browser_close, _cBrowser.cast(), 1024 * 1024);
    if (_cFinalizer == nullptr) {
      close();
      throwLatestNativeError();
    }
  }

  /// Closes and cleans up all resources used by this ObjectBrowser.
  void close() {
    if (_cBrowser.address != 0) {
      final errors = List.filled(2, 0);
      if (_cFinalizer != nullptr) {
        errors[0] = C.dartc_detach_finalizer(_cFinalizer, this);
      }
      errors[1] = C.browser_close(_cBrowser);
      _cBrowser = nullptr;
      errors.forEach(checkObx);
    }
  }

  /// Returns if the browser is already closed and can no longer be used.
  bool isClosed() => _cBrowser.address == 0;

  /// Port the Browser listens on. This is especially useful if the port was
  /// assigned automatically (a "0" port was used in the [bindUri]).
  late final int port = () {
    final result = C.browser_port(_ptr);
    reachabilityFence(this);
    if (result == 0) throwLatestNativeError();
    return result;
  }();
}
