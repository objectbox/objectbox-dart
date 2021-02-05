import 'dart:ffi';

import 'package:ffi/ffi.dart' show allocate, free;

import 'bindings/bindings.dart';
import '../common.dart';

/// Returns the underlying ObjectBox-C library version.
Version libraryVersion() {
  var majorPtr = allocate<Int32>(),
      minorPtr = allocate<Int32>(),
      patchPtr = allocate<Int32>();

  try {
    C.version(majorPtr, minorPtr, patchPtr);
    return Version(majorPtr.value, minorPtr.value, patchPtr.value);
  } finally {
    free(majorPtr);
    free(minorPtr);
    free(patchPtr);
  }
}
