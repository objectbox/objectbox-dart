import 'dart:ffi' as ffi;
import 'package:objectbox/src/bindings/bindings.dart';
import 'package:objectbox/src/bindings/helpers.dart';
import "package:test/test.dart";

void main() {
  // Prior to Dart 2.6, the exception wasn't accessible in the core so the text wasn't reported
  test("error reporting works", () {
    final cStore = bindings.obx_store_open(ffi.nullptr);

    // sanity check - the result is a null pointer
    expect(cStore, isA<ffi.Pointer>().having((ptr) => ptr.address, "address", equals(0)));

    final error = latestNativeError();
    expect(error.nativeMsg, matches('Argument .+ must not be null'));
  });
}
