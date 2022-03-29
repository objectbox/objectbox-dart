import 'dart:io';
import 'dart:typed_data';

import 'package:objectbox_demo/model.dart';
import 'package:objectbox_demo/objectbox.g.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  late final Store store;

  setUp(() async {
    final dir = Directory('testdb');
    final dirExists = await dir.exists();
    if (dirExists) {
      await dir.delete(recursive: true);
    }
    store = Store(getObjectBoxModel(), directory: dir.path);
  });

  tearDown(() {
    store.close;
  });

  test('BoxStore test', () async {
    final products = [
      Product(
          name: "product-1",
          category: "category-1",
          categoryId: 1,
          price: 88.0,
          weight: 5.0,
          isRefunded: false)
    ];

    final billPdf = Pdf(
        pdfData: Uint8List.fromList([1, 2, 3]),
        purchaseDate: DateTime.now(),
        customerName: "Alice",
        totalAmount: 1234,
        paymentStatus: PaymentStatus.unPaid,
        products: ToMany(items: products) //<------- this is the product list
        );

    var pdfBox = store.box<Pdf>();
    // Pdf.id is 0, so will insert and assign ID.
    pdfBox.put(billPdf);

    final loadedPdf = pdfBox.get(billPdf.id)!;
    expect(loadedPdf.products[0].price, 88.0);
    expect(loadedPdf.products[0].weight, 5.0);
  });
}
