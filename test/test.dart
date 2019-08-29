import "../lib/objectbox.dart";

import "../lib/src/bindings/bindings.dart";

//import "package:flat_buffers/flat_buffers.dart" as fb;



@Entity(id: 1, uid: 1)
class Note {
    @Id(id: 1, uid: 1001)
    int id;

    @Property(id: 2, uid: 1002)
    String text;
}

main() {
    print("version: ${Common.version()}  /  ${Common.versionString()}");

    var model = Model([Note]);
    var store = Store(model);
    store.close();
}
