import 'model.dart';
import 'objectbox.g.dart'; // created by `flutter pub run build_runner build`

/// Provides access to the ObjectBox Store throughout the app.
///
/// Initialized in the apps main function.
class ObjectBox {
  Store? _store;

  /// A Box of notes.
  late final Box<Note> noteBox;

  /// A stream of all notes ordered by date.
  late final Stream<Query<Note>> queryStream;

  /// Initialize the store.
  Future<void> init() async {
    // Future<Store> openStore() {...} is defined in the generated objectbox.g.dart
    final store = await openStore();
    _store = store;

    noteBox = Box<Note>(store);
    final qBuilder = noteBox.query()
      ..order(Note_.date, flags: Order.descending);
    queryStream = qBuilder.watch(triggerImmediately: true);

    // Add some demo data if the box is empty.
    if (noteBox.isEmpty()) {
      _putDemoData();
    }
  }

  /// Returns the open Store for this app or throws.
  Store get store {
    final store = _store;
    if (store != null) {
      return store;
    } else {
      throw Exception('Store was not initialized on app launch');
    }
  }

  void _putDemoData() {
    final demoNotes = [
      Note('Quickly add a note by writing text and pressing Enter'),
      Note('Delete notes by tapping on one'),
      Note('Write a demo app for ObjectBox')
    ];
    noteBox.putMany(demoNotes);
  }
}
