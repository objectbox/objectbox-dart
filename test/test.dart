import "../lib/objectbox.dart";

//import "package:flat_buffers/flat_buffers.dart" as fb;



@Entity(id: 1, uid: 1)
class Note {
    @Id(id: 1, uid: 1001, type: Type.Long)
    int id;

    @Property(id: 2, uid: 1002)
    String text;
}

main() {
    print("version: ${Common.version()}  /  ${Common.versionString()}");

    var box = Box([Note]);
    box.close();
}
