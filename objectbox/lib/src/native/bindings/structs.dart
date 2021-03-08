import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'bindings.dart';

// ignore_for_file: public_member_api_docs
// ignore_for_file: camel_case_types

/// Execute the given function, managing the resources consistently
R executeWithIdArray<R>(List<int> items, R Function(Pointer<OBX_id_array>) fn) {
  // allocate a temporary structure
  final ptr = malloc<OBX_id_array>();

  // fill it with data
  final array = ptr.ref;
  array.count = items.length;
  array.ids = malloc<Uint64>(items.length);
  for (var i = 0; i < items.length; ++i) {
    array.ids[i] = items[i];
  }

  // call the function with the structure and free afterwards
  try {
    return fn(ptr);
  } finally {
    malloc.free(array.ids);
    malloc.free(ptr);
  }
}

extension NativeStringArrayAccess on Pointer<OBX_string_array> {
  List<String> toDartStrings() {
    final cArray = ref;
    final items = cArray.items.cast<Pointer<Utf8>>();
    return List<String>.generate(cArray.count, (i) => items[i].toDartString());
  }
}
