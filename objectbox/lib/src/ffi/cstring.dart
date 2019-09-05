import "dart:ffi";

// wrapper for a null-terminated array of characters in memory ("c-style string")
class CString {
    Pointer<Uint8> _ptr;

    CString(String dartStr) {                                   // if this constructor is used, ".free" needs to be called on this instance
        _ptr = Pointer.allocate(count: dartStr.length + 1);
        for(int i = 0; i < dartStr.length; ++i)
            _ptr.elementAt(i).store(dartStr.codeUnitAt(i));
        _ptr.elementAt(dartStr.length).store(0);
    }

    CString.fromPtr(this._ptr);

    String get val {
        String ret = "", c;
        int i = 0;
        while((c = String.fromCharCode(_ptr.elementAt(i++).load<int>())).codeUnitAt(0) != 0)          // TODO: unicode support
            ret += c;
        return ret;
    }

    String toString() => val;
    Pointer<Uint8> get ptr => _ptr;
    void free() => _ptr.free();
}
