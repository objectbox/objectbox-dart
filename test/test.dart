import "../lib/objectbox.dart";

@Entity(id: 1, uid: 1)
class Note {
    @Id(id: 1, uid: 1001, type: Type.Long)
    int id;

    @Property(id: 2, uid: 1002)
    String text;

    Note(this.text);
}

main() {
    var store = Store([Note]);
    var box = Box<Note>(store);
    box.put(Note("Hello"));
    store.close();
}
