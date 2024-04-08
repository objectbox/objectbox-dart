# objectbox_demo_sync

## Getting Started with ObjectBox Sync in Flutter / Dart

This project contains the Flutter version of the Sync example from the [objectbox-examples](https://github.com/objectbox/objectbox-examples) repository.

You need to have a Sync Trial and run the Sync Server to run the demo --> Apply for the [Sync Trial here](https://objectbox.io/sync/).

Also, do check out the [Sync Docs](https://sync.objectbox.io/).

The basic steps to get this demo running (assuming you have a working Flutter setup):

```
# Set up project, get latest dependencies
flutter pub upgrade

# Generate model and code files for ObjectBox
dart run build_runner build

# Run the app in debug mode
flutter run
```

Optional: depending on your setup you might have to adjust the Sync server address in [objectbox.dart](/lib/objectbox.dart).
