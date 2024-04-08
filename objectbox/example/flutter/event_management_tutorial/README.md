# Event Management Flutter Tutorial with ObjectBox

This is the project from the Event Management tutorial on YouTube:

[![Watch the video](https://img.youtube.com/vi/6YPSQPS_bhU/hqdefault.jpg)](https://youtu.be/6YPSQPS_bhU)

## File structure
```
\--objectbox_flutter_tutorial
    \--event_manager_base
    \--many_to_many
```

- The `event_manager` folder includes the project from the first half of the tutorial where we covered
  modeling and working with one-to-one and one-to-many relationships.
- The `many_to_many` folder contains
  the final extension of the application where we change the task managing section into a many-to-many
  relationship.

## Running the Applications

### Change the directory into one of the folders in this repository:

```
cd event_manager (or cd many_to_many)
```

### Install your dependencies:

```
flutter pub get
```

### Generate the binding code :

```
dart run build_runner build
```

### Run the project on your preferred emulator:

```
flutter run
```
