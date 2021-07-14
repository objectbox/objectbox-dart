import 'dart:convert';
import 'dart:io';

import 'package:objectbox/objectbox.dart';
import 'package:test/test.dart';

import 'entity.dart';
import 'test_env.dart';

void main() {
  late TestEnv env;

  setUp(() {
    env = TestEnv('browser');
  });

  tearDown(() => env.close());

  test('browser', () async {
    env.box.put(TestEntity.filled());

    final browser = Browser(env.store);

    // Check that it serves requests and has correct permissions configured.
    final response = await HttpClient()
        .get('127.0.0.1', browser.port, '/api/v2/auth-info')
        .then((request) => request.close());
    expect(response.statusCode, 200);
    expect(await response.transform(utf8.decoder).join(''),
        '{"auth":false,"permissions":{"modelRead":true,"modelWrite":true,"objectsRead":true,"objectsWrite":true,"runtimeRead":true,"runtimeWrite":true}}');

    expect(browser.isClosed(), isFalse);
    browser.close();
    expect(browser.isClosed(), isTrue);
    browser.close(); // does nothing
  },
      skip: Browser.isAvailable()
          ? null
          : 'ObjectBrowser is not available in the loaded library');
}
