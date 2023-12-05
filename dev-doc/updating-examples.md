# Updating Flutter examples

First, make sure to switch your Flutter SDK to the lowest version the ObjectBox packages support
(see pubspec.yaml files).

Then, in the example directory delete the platform-specific directories.

Then, run `flutter create --platforms=android,ios,linux,macos,windows .` to re-create these files.

Then, remove the created default test files and manually review the changes and commit what's necessary.

Check changes do not break the example in any way, make additional changes as required.

Compare against a clean Flutter template (run `create` in an empty folder) to see if updates to
other files like pubspec.yaml are needed.
