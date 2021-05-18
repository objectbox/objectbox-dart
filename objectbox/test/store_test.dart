import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

import 'objectbox.g.dart';

void main() {
  test('store create close multiple', () {
    final dir = Directory('testdata-store');
    if (dir.existsSync()) dir.deleteSync(recursive: true);

    for (var i = 0; i < 1000; i++) {
      final store = Store(getObjectBoxModel(), directory: dir.path);
      store.close();
    }
  });

  test('store create close multiple async', () async {
    final dir = Directory('testdata-store');
    if (dir.existsSync()) dir.deleteSync(recursive: true);

    for (var i = 0; i < 100; i++) {
      final createStoreFuture = Future.delayed(const Duration(milliseconds: 1),
          () => Store(getObjectBoxModel(), directory: dir.path));
      final store = await createStoreFuture;
      store.close();
    }
  });
}
