import "../lib/objectbox.dart";
import "package:utf/src/utf8.dart";

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
    insertNote(box, decodeUtf8([104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]));
    insertNote(box, decodeUtf8([228, 189, 160, 229, 165, 189, 228, 184, 150, 231, 149, 140, 33]));
    insertNote(box, decodeUtf8([65, 104, 111, 106, 32, 115, 118, 196, 155, 116, 101, 33]));
    store.close();
}

insertNote(Box<Note> box, String str) {
    var note = Note.construct(str);
    box.put(note);

    print("new note got id ${note.id}");
    print("refetched note: ${box.getById(note.id)}");
}
