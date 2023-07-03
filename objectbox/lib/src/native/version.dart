import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../common.dart';
import 'bindings/bindings.dart';

/// Returns the underlying ObjectBox-C library version.
Version libraryVersion() {
  final majorPtr = malloc<Int>(),
      minorPtr = malloc<Int>(),
      patchPtr = malloc<Int>();

  try {
    C.version(majorPtr, minorPtr, patchPtr);
    return Version(majorPtr.value, minorPtr.value, patchPtr.value);
  } finally {
    malloc.free(majorPtr);
    malloc.free(minorPtr);
    malloc.free(patchPtr);
  }
}
