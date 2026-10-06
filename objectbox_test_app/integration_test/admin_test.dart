import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:objectbox_test_app/entity.dart';
import 'package:objectbox_test_app/objectbox.g.dart';

import 'test_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TestEnv env;

  setUp(() async {
    env = await TestEnv.create('testdata-admin');
  });

  tearDown(() => env.close());

  // These tests require that the Android database library dependency added by
  // the ObjectBox Flutter package is excluded and instead one with the Admin
  // feature is included in android/app/build.gradle.kts.
  test('Admin is available', () {
    expect(Admin.isAvailable(), isTrue);
  });

  group(
    'Tests if Admin is available',
    () {
      test('Admin instance works', () async {
        env.store.box<TestEntity>().put(TestEntity(tString: 'Hello'));

        final admin = Admin(env.store);

        // Check that it serves requests and has correct permissions configured.
        final response = await HttpClient()
            .get('127.0.0.1', admin.port, '/api/v2/auth-info')
            .then((request) => request.close());
        expect(response.statusCode, 200);
        expect(
          await response.transform(utf8.decoder).join(''),
          '{"auth":false,"permissions":{"modelRead":true,"modelWrite":true,"objectsRead":true,"objectsWrite":true,"runtimeRead":true,"runtimeWrite":true,"syncLogin":true,"syncWrite":true}}',
        );

        expect(admin.isClosed(), isFalse);
        admin.close();
        expect(admin.isClosed(), isTrue);
        admin.close(); // does nothing
      });

      test('Admin create failure throws', () async {
        // Occupy the port so starting the Admin server fails: it must throw
        // (previously the null result was not checked and the Admin object was
        // created in an already-closed state, failing only on later use).
        final socket = await ServerSocket.bind('127.0.0.1', 0);
        addTearDown(socket.close);
        expect(
          () => Admin(env.store, bindUri: 'http://127.0.0.1:${socket.port}'),
          throwsA(
            isA<ObjectBoxException>().having(
              (e) => e.message,
              'message',
              contains('failed to create ObjectBox Admin'),
            ),
          ),
        );
      });
    },
    skip:
        Admin.isAvailable()
            ? null
            : 'Admin is not available in the loaded library',
  );
}
