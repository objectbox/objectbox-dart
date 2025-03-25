# Testing and updating Dart and Flutter SDKs and dependencies

## Testing SDKs

Officially the Dart developers only [commit to release security fixes](https://dart.dev/security)
for the latest version of the Dart SDK. The Flutter developers have so far not released fixes for a
previous minor version of the Flutter SDK.

[Packages specify](https://dart.dev/tools/pub/pubspec#sdk-constraints) a minimum supported Dart and
optionally Flutter SDK. And allow any new not major Dart SDK (and technically 
[any new Flutter SDK](https://dart.dev/tools/pub/pubspec#flutter-sdk-constraints)).

So packages should work with the latest allowed SDKs (tools, APIs), but remain compatible with the
lowest allowed SDKs (APIs, language features).

Based on that, the ObjectBox packages should be

- **tested with the latest available Flutter and Dart SDK** and
- SDKs matching **the lowest supported Dart and Flutter version**.

Note: regarding API compatibility, the issue is that the tools won't error if an API is used that
is not available in the lowest supported SDK. Testing with an older SDK is a workaround for this.

## Updating required SDKs and dependencies

The pub tool prevents upgrading a dependency of an application or library when

- its highest allowed Dart or Flutter SDK, or
- the highest allowed version of one of its shared transitive dependencies

is too low. So assume that applications or libraries may not support the most recent SDKs and 
dependencies, but are safe from breaking changes.

Based on that, ObjectBox packages

- may require the latest, but **should require at most the latest major version of a dependency** 
  and
- may require the latest, but **should require the lowest version of the Dart and Flutter SDK
  required by dependencies** and
- to simplify testing, **all packages should require the same SDK versions**.
