// Web (stub) implementation of transactions: mirrors the public API of
// `../native/transaction.dart` so the package compiles for the web platform,
// but throws `UnsupportedError` at runtime. See tracking issue #185.
// ignore_for_file: public_member_api_docs

import 'package:meta/meta.dart';

import '../store.dart';
import '../transaction.dart' show TxMode;
import 'unsupported.dart';

@internal
class Transaction {
  final TxMode mode;

  Transaction(Store store, this.mode) {
    throwUnsupportedOnWeb();
  }

  void successAndClose() => throwUnsupportedOnWeb();

  void abortAndClose() => throwUnsupportedOnWeb();
}
