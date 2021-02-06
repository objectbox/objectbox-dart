// Note: this is just for the initial development.
// Later, the same tests (e.g. `box_test.dart`) will run both on VM and browser.
// run with: `pub run test -p chrome test/web_test.dart`

// Currently, we're using a custom `web_test.html` to load `lib/objectbox.js`.
// This file wouldn't be necessary if we didn't need to load the javascript.
// It would be impractical to have such a file for all tests so maybe we can
// add a <script src="..." /> object dynamically from dart using package:html
// in test `setUp()`? Similarly to what package/test/dart.js does from JS.

// Since the early dev version of the JS has different APIs (e.g. Store
// constructor) than the native version, don't run on `vm`, only in the browser.
@TestOn('browser')

import 'package:test/test.dart';
import 'package:objectbox/src/web/number.dart';

void main() {
  test('test JS/TS integration', () {
    // `double` is a JS function
    expect(double(4), equals(8));
  });
}
