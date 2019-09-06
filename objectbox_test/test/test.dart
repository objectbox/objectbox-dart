import "package:objectbox/objectbox.dart";
part "test.g.dart";

@Entity(id: 1, uid: 1)
class Note {
    @Id(id: 1, uid: 1001)
    int id;

    @Property(id: 2, uid: 1002)
    String text;

    Note();
    Note.construct(this.text);
    toString() => "Note{id: $id, text: $text}";
}

main() {
    var store = Store([[Note, Note_OBXDefs]]);
    var box = Box<Note>(store);

    var note = Note.construct("Hello 😄");
    note.id = box.put(note);
    print("new note got id ${note.id}");
    print("refetched note: ${box.getById(note.id)}");
    
    store.close();
}
