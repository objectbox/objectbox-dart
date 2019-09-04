import "dart:ffi";

import "bindings/bindings.dart";
import "ffi/cstring.dart";

class Common {
    static List<int> version() {
        Pointer<Int32> majorPtr = Pointer<Int32>.allocate(), minorPtr = Pointer<Int32>.allocate(), patchPtr = Pointer<Int32>.allocate();
        bindings.obx_version(majorPtr, minorPtr, patchPtr);
        var ret = [majorPtr.load<int>(), minorPtr.load<int>(), patchPtr.load<int>()];
        majorPtr.free();
        minorPtr.free();
        patchPtr.free();
        return ret;
    }

    static String versionString() {
        return CString.fromPtr(bindings.obx_version_string()).val;
    }

    static String lastErrorString([err]) {
        if(err != null)
            return "code $err";

        int last = bindings.obx_last_error_code();
        int last2 = bindings.obx_last_error_secondary();
        String desc = CString.fromPtr(bindings.obx_last_error_message()).val;
        return "code $last, $last2 ($desc)";
    }
}

class ObjectBoxException {
    final String message;
    ObjectBoxException(msg) : message = "ObjectBoxException: " + msg;

    String toString() => message;
}
