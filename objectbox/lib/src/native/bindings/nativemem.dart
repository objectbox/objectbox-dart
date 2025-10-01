import 'dart:ffi';
import 'dart:io';

/// Provides native memory manipulation, operating on FFI `Pointer<Void>`.

/// memset(ptr, value, num) sets the first num bytes of the block of memory
/// pointed by ptr to the specified value (interpreted as an uint8).
final DartMemset memset =
    _stdlib.lookupFunction<_CMemset, DartMemset>('memset');

final DartMemcpy? _memcpyNative = _lookupMemcpyOrNull();

DartMemcpy? _lookupMemcpyOrNull() {
  try {
    return _stdlib.lookupFunction<_CMemcpy, DartMemcpy>('memcpy');
  } catch (_) {
    return null;
  }
}

/// If the native memcpy function is not available
/// and a Dart implementation is used.
final isMemcpyNotAvailable = _memcpyNative == null;

// ignore: prefer_function_declarations_over_variables
final DartMemcpy _memcpyDart = (dest, src, length) {
  dest
      .asTypedList(length)
      .setAll(0, src.asTypedList(length).getRange(0, length));
};

/// memcpy (destination, source, num) copies the values of num bytes from the
/// data pointed to by source to the memory block pointed to by destination.
///
/// Note: the native memcpy might not be available
/// (e.g. for Flutter on iOS 15 simulator), then a Dart implementation is used
/// to copy data via asTypedList (which is much slower).
/// https://github.com/objectbox/objectbox-dart/issues/313
final DartMemcpy memcpy = _memcpyNative ?? _memcpyDart;

// FFI signature
/// Used for internal testing only.
typedef DartMemset = void Function(Pointer<Uint8>, int, int);
typedef _CMemset = Void Function(Pointer<Uint8>, Int32, IntPtr);

/// Used internally only.
typedef DartMemcpy = void Function(Pointer<Uint8>, Pointer<Uint8>, int);
typedef _CMemcpy = Void Function(Pointer<Uint8>, Pointer<Uint8>, IntPtr);

final DynamicLibrary _stdlib = Platform.isWindows // no .process() on windows
    ? DynamicLibrary.open('vcruntime140.dll') // required by objectbox.dll
    : DynamicLibrary.process();
