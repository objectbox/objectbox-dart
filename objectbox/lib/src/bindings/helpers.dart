import "dart:ffi";
import "dart:typed_data" show Uint8List;
import "constants.dart";
import "../common.dart";

checkObx(errorCode) {
    if(errorCode != OBXError.OBX_SUCCESS)
        throw ObjectBoxException(Common.lastErrorString(errorCode));
}

checkObxPtr(Pointer ptr, String msg) {
    if(ptr == null || ptr.address == 0)
        throw ObjectBoxException(msg);
}

loadMemory(Pointer<Uint8> data, int size) {
    if(data == null || data.address == 0)
        throw Exception("invalid memory pointer: $data");
    if(size < 0)
        throw Exception("invalid memory region size: $size");
    var buffer = new Uint8List(size);
    for(int i = 0; i < size; ++i)
        buffer[i] = data.elementAt(i).load<int>();
    return buffer;
}
