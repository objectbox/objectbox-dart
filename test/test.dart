import "package:reflectable/reflectable.dart";
import "../lib/objectbox.dart";
import "test.reflectable.dart";

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
    initializeReflectable();

    var store = Store([Note]);
    print(Note.reflect());
    //var box = Box<Note>(store);

    /*var note = Note.construct("Hello");
    box.put(note);
    print("new note got id ${note.id}");
    print("refetched note: ${box.getById(note.id)}");*/
    
    store.close();
}
