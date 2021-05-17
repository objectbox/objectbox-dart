import 'dart:ffi';
import 'dart:io';

/// Provides native memory manipulation, operating on FFI Pointer<Void>.

/// memset(ptr, value, num) sets the first num bytes of the block of memory
/// pointed by ptr to the specified value (interpreted as an uint8).
final _dart_memset memset =
    _stdlib.lookupFunction<_c_memset, _dart_memset>('memset');

/// memcpy (destination, source, num) copies the values of num bytes from the
/// data pointed to by source to the memory block pointed to by destination.
final _dart_memcpy memcpy =
    _stdlib.lookupFunction<_c_memcpy, _dart_memcpy>('memcpy');

// FFI signature
typedef _dart_memset = void Function(Pointer<Uint8>, int, int);
typedef _c_memset = Void Function(Pointer<Uint8>, Int32, IntPtr);

typedef _dart_memcpy = void Function(Pointer<Uint8>, Pointer<Uint8>, int);
typedef _c_memcpy = Void Function(Pointer<Uint8>, Pointer<Uint8>, IntPtr);

final DynamicLibrary _stdlib = Platform.isWindows // no .process() on windows
    ? DynamicLibrary.open('vcruntime140.dll') // required by objectbox.dll
    : DynamicLibrary.process();
