import "dart:ffi";
import "package:utf/src/utf8.dart";

// TODO check if revamp structs are relevant (https://github.com/dart-lang/sdk/issues/37229)
// wrapper for a null-terminated array of characters in memory ("c-style string")
class CString {
    Pointer<Uint8> _ptr;

    // if this constructor is used, ".free" needs to be called on this instance
    CString(String dartStr) {
        final ints = encodeUtf8(dartStr);
        _ptr = Pointer<Uint8>.allocate(count: ints.length + 1);
        for(int i = 0; i < ints.length; ++i) {
            _ptr.elementAt(i).store(ints.elementAt(i));
        }
        _ptr.elementAt(ints.length).store(0);
    }

    CString.fromPtr(this._ptr);

    String get val {
        List<int> utf8CodePoints = new List<int>();
        int element;

        for(int i = 0; element != 0; i++) {
            element = _ptr.elementAt(i).load<int>();
            utf8CodePoints.add(element);
        }

        return decodeUtf8(utf8CodePoints);
    }

    String toString() => val;
    Pointer<Uint8> get ptr => _ptr;
    void free() => _ptr.free();
}
