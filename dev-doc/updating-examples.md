# Updating Flutter examples

First, make sure to switch your Flutter SDK to the lowest version that should be supported
(at minimum what the Flutter packages require, see their pubspec.yaml files; but typically higher
due to dependency or tooling requirements):

```shell
# Make sure to close IDEs or tools using the Flutter or Dart SDK first.
# Then, in the Flutter SDK directory:
git checkout 3.16.9
flutter doctor
```

Then, for an example in its directory delete the platform-specific directories and the

- `.gitignore`
- `analysis_options.yaml`
- `pubspec.yaml`

files.

Then, run `flutter create --platforms=android,ios,linux,macos,windows .` to create empty example
files.

Then, remove the created default widget test file. Review the changes, restore any required changes
(like in Podfile, build scripts, project files, the files mentioned above...). This can be helped by
running `flutter pub upgrade` and `flutter run` on each platform (with the same Flutter SDK version!).

Then, commit only what's necessary.

Then, adjust the other examples accordingly.
