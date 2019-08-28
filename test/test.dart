import "../lib/objectbox.dart";
import "../lib/src/bindings/bindings.dart";

main() {
    print(OBXCommon.version());

    var model = bindings.obx_model_create();
    bindings.obx_model_free(model);
    print(model);
}
