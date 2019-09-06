import "dart:ffi";
import "constants.dart";
import "../common.dart";

checkObx(errorCode) {
    if(errorCode != OBXErrors.OBX_SUCCESS)
        throw ObjectBoxException(Common.lastErrorString(errorCode));
}

checkObxPtr(Pointer ptr, String msg) {
    if(ptr == null || ptr.address == 0)
        throw ObjectBoxException(msg);
}
