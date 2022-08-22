import 'model.dart';
import 'objectbox.g.dart'; // created by `flutter pub run build_runner build`

/// Provides access to the ObjectBox Store throughout the app.
///
/// Create this in the apps main function.
class ObjectBox {
  /// The Store of this app.
  late final Store store;

  /// A Box of notes.
  late final Box<Note> noteBox;

  ObjectBox._create(this.store) {
    noteBox = Box<Note>(store);

    // Add some demo data if the box is empty.
    if (noteBox.isEmpty()) {
      _putDemoData();
    }
  }

  /// Create an instance of ObjectBox to use throughout the app.
  static Future<ObjectBox> create() async {
    // Future<Store> openStore() {...} is defined in the generated objectbox.g.dart
    final store = await openStore();
    return ObjectBox._create(store);
  }

  void _putDemoData() {
    final demoNotes = [
      Note('Quickly add a note by writing text and pressing Enter'),
      Note('Delete notes by tapping on one'),
      Note('Write a demo app for ObjectBox')
    ];
    store.runInTransactionAsync(TxMode.write, _putNotesInTx, demoNotes);
  }

  Stream<List<Note>> getNotes() {
    // Query for all notes, sorted by their date.
    // https://docs.objectbox.io/queries
    final builder = noteBox.query()..order(Note_.date, flags: Order.descending);
    // Build and watch the query,
    // set triggerImmediately to emit the query immediately on listen.
    return builder
        .watch(triggerImmediately: true)
        // Map it to a list of notes to be used by a StreamBuilder.
        .map((query) => query.find());
  }

  static void _putNotesInTx(Store store, List<Note> notes) =>
      store.box<Note>().putMany(notes);

  /// Add a note within a transaction.
  ///
  /// To avoid frame drops, run ObjectBox operations that take longer than a
  /// few milliseconds, e.g. putting many objects, in an isolate with its
  /// own Store instance.
  /// For this example only a single object is put which would also be fine if
  /// done here directly.
  Future<void> addNote(String text) =>
      store.runInTransactionAsync(TxMode.write, _addNoteInTx, text);

  /// Note: due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983)
  /// not using a closure as it may capture more objects than expected.
  /// These might not be send-able to an isolate. See Store.runAsync for details.
  static void _addNoteInTx(Store store, String text) {
    // Perform ObjectBox operations that take longer than a few milliseconds
    // here. To keep it simple, this example just puts a single object.
    store.box<Note>().put(Note(text));
  }
}
