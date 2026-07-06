@TestOn('browser')
library;

import 'package:test/test.dart';
import 'package:web_test/models.dart';
import 'package:web_test/objectbox.g.dart';

void main() {
  test('generated model + query property statics load without native lib', () {
    expect(Person_.name, isNotNull);
    expect(Person_.embedding, isNotNull);
    expect(House_.address, isNotNull);
    expect(getObjectBoxModel(), isNotNull);
  });

  test('remaining unsupported APIs throw', () async {
    final store = openStore(directory: 'memory:stub-test');
    await store.ready;
    expect(() => store.reference, throwsUnsupportedError);
    store.close();
  });

  test('availability checks are false, not throwing', () {
    expect(Admin.isAvailable(), isFalse);
    expect(Sync.isAvailable(), isFalse);
    expect(Store.isOpen('never-opened'), isFalse);
  });
}
