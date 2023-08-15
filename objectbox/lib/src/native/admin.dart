import 'dart:ffi';

import 'bindings/bindings.dart';
import 'bindings/helpers.dart';
import 'store.dart';

/// ObjectBox Admin allows you to explore the database in a regular web browser.
///
/// ```dart
/// if (Admin.isAvailable()) {
///   // Keep a reference until no longer needed or manually closed.
///   admin = Admin(store);
/// }
/// ```
///
/// Admin runs directly on your device or on your development machine.
/// Behind the scenes this works by bundling a simple HTTP server into ObjectBox
/// when building your app. If triggered, it will then provide a basic web
/// interface to the data and schema.
///
/// Note: ObjectBox Admin is currently supported for Android apps only.
/// [Additional configuration](https://docs.objectbox.io/data-browser) is
/// required.
class Admin implements Finalizable {
  late Pointer<OBX_admin> _cAdmin;

  /// Runs native close function on [_cAdmin] if this is garbage collected.
  ///
  /// Keeps the finalizer itself reachable (static), otherwise it might be
  /// disposed of before the finalizer callback gets a chance to run.
  static final _finalizer = NativeFinalizer(C.addresses.admin_close.cast());

  @pragma('vm:prefer-inline')
  Pointer<OBX_admin> get _ptr =>
      isClosed() ? throw StateError('Admin already closed') : _cAdmin;

  /// Whether the loaded ObjectBox native library supports Admin.
  static bool isAvailable() => C.has_feature(OBXFeature.Admin);

  /// Creates an ObjectBox Admin associated with the given store and options.
  Admin(Store store, {String bindUri = 'http://127.0.0.1:8090'}) {
    if (!isAvailable()) {
      throw UnsupportedError(
          'Admin is not available in the loaded ObjectBox runtime library.');
    }
    initializeDartAPI();

    final opt = checkObxPtr(C.admin_opt());
    try {
      checkObx(C.admin_opt_store(opt, InternalStoreAccess.ptr(store)));
      checkObx(C.admin_opt_user_management(opt, false));
      withNativeString(bindUri,
          (Pointer<Char> cStr) => checkObx(C.admin_opt_bind(opt, cStr)));
    } catch (_) {
      C.admin_opt_free(opt);
      rethrow;
    }

    _cAdmin = C.admin(opt);

    _finalizer.attach(this, _cAdmin.cast(),
        detach: this, externalSize: 1024 * 1024);
  }

  /// Closes and cleans up all resources used by this Admin.
  void close() {
    if (isClosed()) {
      return;
    }
    _finalizer.detach(this);
    final error = C.admin_close(_cAdmin);
    _cAdmin = nullptr;
    checkObx(error);
  }

  /// Returns if the admin is already closed and can no longer be used.
  bool isClosed() => _cAdmin.address == 0;

  /// Port the admin listens on. This is especially useful if the port was
  /// assigned automatically (a "0" port was used in the [bindUri]).
  late final int port = () {
    final result = C.admin_port(_ptr);
    if (result == 0) throwLatestNativeError();
    return result;
  }();
}
