import 'dart:convert';
import 'dart:io';

import 'package:objectbox/objectbox.dart';
import 'package:test/test.dart';

import 'entity.dart';
import 'test_env.dart';

void main() {
  late TestEnv env;

  setUp(() {
    env = TestEnv('admin');
  });

  tearDown(() => env.closeAndDelete());

  // Note: this test currently requires a C library with Sync server,
  // so it is not run on public CI and must be run manually.
  test('admin', () async {
    env.box.put(TestEntity.filled());

    final admin = Admin(env.store);

    // Check that it serves requests and has correct permissions configured.
    final response = await HttpClient()
        .get('127.0.0.1', admin.port, '/api/v2/auth-info')
        .then((request) => request.close());
    expect(response.statusCode, 200);
    expect(await response.transform(utf8.decoder).join(''),
        '{"auth":false,"permissions":{"modelRead":true,"modelWrite":true,"objectsRead":true,"objectsWrite":true,"runtimeRead":true,"runtimeWrite":true}}');

    expect(admin.isClosed(), isFalse);
    admin.close();
    expect(admin.isClosed(), isTrue);
    admin.close(); // does nothing
  },
      skip: Admin.isAvailable()
          ? null
          : 'Admin is not available in the loaded library');

  test('admin not available', () {
    expect(
        () => Admin(env.store),
        throwsA(predicate((UnsupportedError e) => e.toString().contains(
            'Admin is not available in the loaded ObjectBox runtime library.'))));
  },
      skip: Admin.isAvailable()
          ? 'Admin is available in the loaded library'
          : false);
}
