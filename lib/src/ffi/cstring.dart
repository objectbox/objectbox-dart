import "dart:ffi";

class CString {
    Pointer<Uint8> _ptr;
    int _len;

    CString(String dartStr) {
        _ptr = allocate(count: dartStr.length + 1);
        for(int i = 0; i < dartStr.length; ++i)
            _ptr.elementAt(i).store(dartStr.codeUnitAt(i));
        _ptr.elementAt(dartStr.length).store(0);
        _len = dartStr.length;
    }

    String get val {
        String ret = "";
        for(int i = 0; i < _len; ++i)
            ret += String.fromCharCode(_ptr.elementAt(i).load<int>());      // TODO: unicode support
        return ret;
    }

    Pointer<Uint8> get ptr => _ptr;
    int get len => _len;
    void free() => _ptr.free();
}
