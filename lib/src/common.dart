import "dart:ffi";

import "bindings/bindings.dart";

class OBXCommon {
    static List<int> version() {
        Pointer<Int32> majorPtr = allocate(),  minorPtr = allocate(), patchPtr = allocate();
        bindings.obx_version(majorPtr, minorPtr, patchPtr);
        return [majorPtr.load<int>(), minorPtr.load<int>(), patchPtr.load<int>()];
    }
}
