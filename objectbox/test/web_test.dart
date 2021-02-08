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
import 'package:objectbox/src/web/number.dart' as webnum;

void main() {
  /// JS Code generated for the [test`] function. Note the inlined dart version.
  /// function() {
  ///    var watch1, num1, i, watch2, num2,
  ///      t1 = objectbox.double.call$1(4);
  ///    G.expect(t1, new D._DeepMatcher(8, 100), null);
  ///    G.expect(8, new D._DeepMatcher(8, 100), null);
  ///    watch1 = new P.Stopwatch();
  ///    $.$get$Stopwatch__frequency();
  ///    watch1.start$0();
  ///    for (num1 = 1, i = 0; i < 10000; ++i)
  ///      num1 = objectbox.double.call$1(num1);
  ///    watch1.stop$0(0);
  ///    P.print("JS call takes: " + P.Duration$(watch1.get$elapsedMicroseconds(), 0).toString$0(0));
  ///    watch2 = new P.Stopwatch();
  ///    $.$get$Stopwatch__frequency();
  ///    watch2.start$0();
  ///    for (num2 = 1, i = 0; i < 10000; ++i)
  ///      num2 *= 2;
  ///    watch2.stop$0(0);
  ///    P.print("Dart call takes: " + P.Duration$(watch2.get$elapsedMicroseconds(), 0).toString$0(0));
  ///    P.print("Factor: " + H.S(watch1.get$elapsedTicks() / 10000 / (watch2.get$elapsedTicks() / 10000)));
  ///    G.expect(num1, new D._DeepMatcher(num2, 100), null);
  ///  }
  test('test1', () {
    num runs = 10000;
    // `double` is a JS function, `double2` is implemented in dart
    expect(webnum.double(4), equals(8));
    expect(webnum.double2(4), equals(8));

    num num1 = 1;
    final watch1 = Stopwatch()..start();
    for (var i = 0; i < runs; i++) {
      // num1 = webnum.double(10);
      num1 = webnum.double(num1);
    }
    watch1.stop();
    print('JS call takes: ${watch1.elapsed}');

    num num2 = 1;
    final watch2 = Stopwatch()..start();
    for (var i = 0; i < runs; i++) {
      // num2 = webnum.double2(10);
      num2 = webnum.double2(num2);
    }
    watch2.stop();
    print('Dart call takes: ${watch2.elapsed}');

    // Results: Dart code is about 7.6 times faster when passing the result as
    // the next param (up to "Infinity"), and 15 times with a constant param.
    final factor = (watch1.elapsedTicks / runs) / (watch2.elapsedTicks / runs);
    print('Factor: $factor');

    expect(num1, equals(num2));
  });
  /// JS Code generated for the [test`] function. Note the inlined dart version.
  /// function() {
  ///    var watch1, num1, i, watch2, num2,
  ///      t1 = objectbox.double.call$1(4);
  ///    G.expect(t1, new D._DeepMatcher(8, 100), null);
  ///    G.expect(8, new D._DeepMatcher(8, 100), null);
  ///    watch1 = new P.Stopwatch();
  ///    $.$get$Stopwatch__frequency();
  ///    watch1.start$0();
  ///    for (num1 = 1, i = 0; i < 10000; ++i)
  ///      num1 = objectbox.double.call$1(num1);
  ///    watch1.stop$0(0);
  ///    P.print("JS call takes: " + P.Duration$(watch1.get$elapsedMicroseconds(), 0).toString$0(0));
  ///    watch2 = new P.Stopwatch();
  ///    $.$get$Stopwatch__frequency();
  ///    watch2.start$0();
  ///    for (num2 = 1, i = 0; i < 10000; ++i)
  ///      num2 *= 2;
  ///    watch2.stop$0(0);
  ///    P.print("Dart call takes: " + P.Duration$(watch2.get$elapsedMicroseconds(), 0).toString$0(0));
  ///    P.print("Factor: " + H.S(watch1.get$elapsedTicks() / 10000 / (watch2.get$elapsedTicks() / 10000)));
  ///    G.expect(num1, new D._DeepMatcher(num2, 100), null);
  ///  }
  test('test1', () {
    num runs = 10000;
    // `double` is a JS function, `double2` is implemented in dart
    expect(webnum.double(4), equals(8));
    expect(webnum.double2(4), equals(8));

    num num1 = 1;
    final watch1 = Stopwatch()..start();
    for (var i = 0; i < runs; i++) {
      // num1 = webnum.double(10);
      num1 = webnum.double(num1);
    }
    watch1.stop();
    print('JS call takes: ${watch1.elapsed}');

    num num2 = 1;
    final watch2 = Stopwatch()..start();
    for (var i = 0; i < runs; i++) {
      // num2 = webnum.double2(10);
      num2 = webnum.double2(num2);
    }
    watch2.stop();
    print('Dart call takes: ${watch2.elapsed}');

    // Results: Dart code is about 7.6 times faster when passing the result as
    // the next param (up to "Infinity"), and 15 times with a constant param.
    final factor = (watch1.elapsedTicks / runs) / (watch2.elapsedTicks / runs);
    print('Factor: $factor');

    expect(num1, equals(num2));
  });
}
