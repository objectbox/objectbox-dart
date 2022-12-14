# Updating Flutter examples

In the example directory delete the platform specific directories.

Then run `flutter create --platforms=android,ios,linux,macos,windows .` to re-create these files.

- Remove the created default test.

Check changes do not break the example in any way, make additional changes as required.

Compare against a clean Flutter template (run `create` in an empty folder) to see if updates to
other files like pubspec.yaml are needed.
