// Web (stub) implementation of the ObjectBox Admin: mirrors the public API of
// `../native/admin.dart` so the package compiles for the web platform, but
// throws `UnsupportedError` at runtime. See tracking issue #185.
// ignore_for_file: public_member_api_docs

import '../store.dart';
import 'unsupported.dart';

/// ObjectBox Admin web interface. Not supported on the web platform.
class Admin {
  /// Whether the Admin interface is available in this runtime: always false
  /// on web, so `if (Admin.isAvailable())` guards keep working unchanged.
  static bool isAvailable() => false;

  Admin(Store store, {String bindUri = 'http://127.0.0.1:8090'}) {
    throwUnsupportedOnWeb();
  }

  void close() => throwUnsupportedOnWeb();

  bool isClosed() => throwUnsupportedOnWeb();

  int get port => throwUnsupportedOnWeb();
}
