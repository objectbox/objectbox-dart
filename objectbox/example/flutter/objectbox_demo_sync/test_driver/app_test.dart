import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  // First, define the Finders and use them to locate widgets from the
  // test suite. Note: the Strings provided to the `byValueKey` method must
  // be the same as the Strings we used for the Keys in step 1.
  final inputTextFinder = find.byValueKey('input');
  final buttonFinder = find.byValueKey('submit');
  final firstItemFinder = find.byValueKey('list_item_0');

  FlutterDriver driver;

  // Connect to the Flutter driver before running any tests.
  setUpAll(() async {
    driver = await FlutterDriver.connect();
  });

  // Close the connection to the driver after the tests have completed.
  tearDownAll(() async => await driver.close());

  test('starts with an empty list', () async {
    await driver.waitForAbsent(firstItemFinder,
        timeout: const Duration(milliseconds: 100));
  });

  test('inserted item appears in the list', () async {
    final text = 'item text';
    await driver.tap(inputTextFinder);
    await driver.enterText(text);
    await driver.tap(buttonFinder);
    expect(await driver.getText(firstItemFinder), text);
  });
}
