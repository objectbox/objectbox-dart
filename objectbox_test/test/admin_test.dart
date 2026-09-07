import 'package:objectbox/objectbox.dart';
import 'package:test/test.dart';

import 'test_env.dart';

void main() {
  late TestEnv env;

  setUp(() {
    env = TestEnv('admin');
  });

  tearDown(() => env.closeAndDelete());

  // Note: the Admin feature is currently only available in the Flutter package
  // for Android (and only when manually changing the Android database library
  // dependency to one that includes it). So tests for the Dart Admin API are in
  // objectbox_test_app/integration_test/admin_test.dart, which is run manually
  // against a device/emulator.

  test('admin not available', () {
    expect(Admin.isAvailable(), isFalse);
    expect(
        () => Admin(env.store),
        throwsA(predicate((UnsupportedError e) => e.toString().contains(
            'Admin is not available in the loaded ObjectBox runtime library.'))));
  });
}
