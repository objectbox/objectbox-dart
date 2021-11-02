import 'dart:ffi';
import 'dart:io';

/// Provides native memory manipulation, operating on FFI Pointer<Void>.

/// memset(ptr, value, num) sets the first num bytes of the block of memory
/// pointed by ptr to the specified value (interpreted as an uint8).
final _dart_memset memset =
    _stdlib.lookupFunction<_c_memset, _dart_memset>('memset');

/// If the native memcpy function should not be used.
///
/// memcpy is not available to Flutter on iOS 15 simulator,
/// so use Dart API to copy data via asTypedList (which is much slower but works).
///
/// https://github.com/objectbox/objectbox-dart/issues/313
final isMemcpyNotAvailable = Platform.isIOS;
final _dart_memcpy _memcpyDart = (dest, src, length) {
  dest
      .asTypedList(length)
      .setAll(0, src.asTypedList(length).getRange(0, length));
};

/// memcpy (destination, source, num) copies the values of num bytes from the
/// data pointed to by source to the memory block pointed to by destination.
final _dart_memcpy memcpy = isMemcpyNotAvailable
    ? _memcpyDart
    : _stdlib.lookupFunction<_c_memcpy, _dart_memcpy>('memcpy');

// FFI signature
typedef _dart_memset = void Function(Pointer<Uint8>, int, int);
typedef _c_memset = Void Function(Pointer<Uint8>, Int32, IntPtr);

typedef _dart_memcpy = void Function(Pointer<Uint8>, Pointer<Uint8>, int);
typedef _c_memcpy = Void Function(Pointer<Uint8>, Pointer<Uint8>, IntPtr);

final DynamicLibrary _stdlib = Platform.isWindows // no .process() on windows
    ? DynamicLibrary.open('vcruntime140.dll') // required by objectbox.dll
    : DynamicLibrary.process();
