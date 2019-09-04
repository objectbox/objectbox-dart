import "dart:ffi";
import "dart:typed_data";
import "package:utf/src/utf8.dart";
import "package:utf/src/utf16.dart";

// TODO check if revamp structs are relevant (https://github.com/dart-lang/sdk/issues/37229)
// wrapper for a null-terminated array of characters in memory ("c-style string")
class CString {
    Pointer<Uint8> _ptr;

    // if this constructor is used, ".free" needs to be called on this instance
    CString(String dartStr) {
        List<int> ints = encodeUtf8(dartStr);
        var utf8Str = Uint8List.fromList(ints);
        _ptr = Pointer<Uint8>.allocate(count: utf8Str.length + 1);
        for(int i = 0; i < utf8Str.length; ++i)
            _ptr.elementAt(i).store(utf8Str.elementAt(i));
        _ptr.elementAt(utf8Str.length).store(0);
    }

    CString.fromPtr(this._ptr);

    String get val {
        List<int> utf8CodePoints = new List<int>();

        int element;
        
        for (int i=0; element != 0; i++) {
	    element = _ptr.elementAt(i).load<int>();
	    utf8CodePoints.add(element);
        }

        return decodeUtf8(utf8CodePoints);
    }

    String toString() => val;
    Pointer<Uint8> get ptr => _ptr;
    void free() => _ptr.free();
}
