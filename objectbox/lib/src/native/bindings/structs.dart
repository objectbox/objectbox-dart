import 'dart:ffi';

import 'package:ffi/ffi.dart' show allocate, free, Utf8;

import 'bindings.dart';

// ignore_for_file: public_member_api_docs
// ignore_for_file: camel_case_types

/// Execute the given function, managing the resources consistently
R executeWithIdArray<R>(List<int> items, R Function(Pointer<OBX_id_array>) fn) {
  // allocate a temporary structure
  final ptr = allocate<OBX_id_array>();

  // fill it with data
  final array = ptr.ref;
  array.count = items.length;
  array.ids = allocate<Uint64>(count: items.length);
  for (var i = 0; i < items.length; ++i) {
    array.ids[i] = items[i];
  }

  // call the function with the structure and free afterwards
  try {
    return fn(ptr);
  } finally {
    free(array.ids);
    free(ptr);
  }
}

class OBX_string_array_wrapper {
  final Pointer<OBX_string_array> _cPtr;

  OBX_string_array_wrapper(this._cPtr);

  List<String> items() {
    final cArray = _cPtr.ref;
    final list = <String>[];
    for (var i = 0; i < cArray.count; i++) {
      list.add(Utf8.fromUtf8(cArray.items.elementAt(i).value.cast<Utf8>()));
    }
    return list;
  }
}
