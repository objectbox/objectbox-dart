import "../lib/objectbox.dart";

import "../lib/src/bindings/bindings.dart";



@Entity(id: 1, uid: 1)
class Note {
    @Id(id: 1, uid: 1001)
    int id;

    @Property(id: 2, uid: 1002)
    String text;
}

main() {
    print("version: ${Common.version()}  /  ${Common.versionString()}");

    print(Model.create([Note]));
}
