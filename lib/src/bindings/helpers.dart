import "constants.dart";
import "../common.dart";

check(cond) {
    if(!cond)
        throw AssertionError();
}

checkObx(err) {
    if(err != OBXErrors.OBX_SUCCESS)
        throw ObjectBoxException(Common.lastErrorString(err));
}
