## 5.4.0

* Migrate Android build to use built-in Kotlin (per the official Flutter
  migration guide: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors).
  Removes the legacy `apply plugin: "kotlin-android"` line and the
  `kotlin-gradle-plugin` classpath from `android/build.gradle`.
* Bump minimum Dart SDK to `^3.12.0` and Flutter to `>=3.44.0`.

See [ObjectBox changelog](https://pub.dev/packages/objectbox/changelog).
