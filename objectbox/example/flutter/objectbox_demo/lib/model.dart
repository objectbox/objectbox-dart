import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:objectbox/objectbox.dart';

import 'objectbox.g.dart';

// ignore_for_file: public_member_api_docs

@Entity()
class Note {
  int id;

  String text;
  String? comment;

  /// Note: Stored in milliseconds without time zone info.
  DateTime date;

  Note(this.text, {this.id = 0, this.comment, DateTime? date})
      : date = date ?? DateTime.now();

  String get dateFormat => DateFormat('dd.MM.yyyy hh:mm:ss').format(date);
}

enum WeightType {kg}

@Entity()
class Product {
  @Id()
  int id;
  String name;
  String category;
  int categoryId;
  WeightType weightType;
  double? price;
  double weight;
  bool isRefunded;

  Product({
    this.id = 0,
    required this.name,
    required this.category,
    required this.categoryId,
    this.weightType = WeightType.kg,
    this.price,
    this.weight = 0,
    this.isRefunded = false,
  });

  Product copy() => Product(
    name: name,
    category: category,
    id: id,
    price: price,
    weight: weight,
    weightType: weightType,
    categoryId: categoryId,
    isRefunded: isRefunded,
  );

}

enum PaymentStatus {
  unPaid
}

@Entity()
class Pdf {
  @Id()
  int id;
  Uint8List pdfData;
  final String customerName;
  @Property(type: PropertyType.date)
  final DateTime purchaseDate;
  ToMany<Product> products; //<----------- the relation
  double totalAmount;
  PaymentStatus paymentStatus;
  @Property(type: PropertyType.date)
  DateTime? updateDate;

  Pdf({
    this.id = 0,
    required this.pdfData,
    required this.purchaseDate,
    required this.customerName,
    required this.totalAmount,
    required this.products,
    this.paymentStatus = PaymentStatus.unPaid,
    this.updateDate,
  });

  int get status => paymentStatus.index;

  set status(int value) {
    paymentStatus = PaymentStatus.values[value];
  }
}
