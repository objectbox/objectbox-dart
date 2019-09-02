import "../lib/objectbox.dart";

@Entity(id: 1, uid: 1)
class Note {
    @Id(id: 1, uid: 1001, type: Type.Long)
    int id;

    @Property(id: 2, uid: 1002)
    String text;

    Note();
    Note.construct(this.text);

    toString() => "Note{id: $id, text: $text}";
}

main() {
    var store = Store([Note]);
    var box = Box<Note>(store);

    var note = Note.construct("Hello");
    box.put(note);
    print("new note got id ${note.id}");
    print("refetched note: ${box.getById(note.id)}");
    
    store.close();
}
