<p align="center">
  <img src="https://raw.githubusercontent.com/objectbox/objectbox-dart/main/.github/logo.png" alt="ObjectBox" width="400px">
</p>

<p align="center">
  <a href="https://docs.objectbox.io/getting-started">Getting Started</a> •
  <a href="https://docs.objectbox.io">Documentation</a> •
  <a href="https://github.com/objectbox/objectbox-dart/tree/main/objectbox/example">Example Apps</a> •
  <a href="https://github.com/objectbox/objectbox-dart/issues">Issues</a>
</p>

<p align="center">
  <a href="https://github.com/objectbox/objectbox-dart/actions/workflows/dart.yml">
    <img src="https://github.com/objectbox/objectbox-dart/actions/workflows/dart.yml/badge.svg" alt="Build and test">
  </a>
  <a href="https://pub.dev/packages/objectbox">
    <img src="https://img.shields.io/pub/v/objectbox.svg?label=pub.dev&logo=dart" alt="pub.dev package">
  </a>
  <a href="https://github.com/objectbox/objectbox-dart/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/objectbox/objectbox-dart?logo=apache" alt="Apache 2.0 license">
  </a>
  <a href="https://twitter.com/ObjectBox_io">
    <img src="https://img.shields.io/twitter/follow/ObjectBox_io?style=flat&logo=twitter" alt="Follow @ObjectBox_io">
  </a>
</p>

# Flutter database for Dart-native objects 💙

Super-fast Flutter database for storing and syncing Dart objects.

**Your opinion matters to us!** Please fill in this 2-minute [Anonymous Feedback Form](https://forms.gle/LvVjN6jfFHuivxZX6).

* 🏁 **High performance** - improving response rates and enabling real-time applications.
* 🪂 **ACID compliant** - Atomic, Consistent, Isolated, Durable.
* 💻 **Multiplatform** - Android, iOS, macOS, Linux, Windows.
* 🌱 **Scalable** - grows with your app, handling millions of objects with ease.

Easy to use
* 🔗 **Relations** - object links / relationships are built-in.
* 💐 **Queries** - filter data as needed, even across relations.
* 🦮 **Statically typed** - compile time checks & optimizations.
* 📃 **Schema migration** - change your model with confidence.

Oh, and there is one more thing...
* 😮 [**Data Sync**](https://objectbox.io/sync/) - keeps data in sync offline or online, between devices and servers.

## Sneak peek - persist Dart objects with ObjectBox 

```dart
@Entity()
class Person {
  int id;

  String firstName;
  String lastName;

  Person({this.id = 0, required this.firstName, required this.lastName});
}

final store = await openStore(); 
final box = store.box<Person>();

var person = Person(firstName: 'Joe', lastName: 'Green');

final id = box.put(person);  // Create

person = box.get(id)!;       // Read

person.lastName = "Black";
box.put(person);             // Update

box.remove(person.id);       // Delete

// find all people whose name start with letter 'J'
final query = box.query(Person_.firstName.startsWith('J')).build();
final people = query.find();  // find() returns List<Person>
```

## Getting Started

**New:** check out our new [Getting Started guide](https://docs.objectbox.io/getting-started).

Depending on if you are building a Flutter or Dart-only app, follow the steps below to start using ObjectBox.

### Flutter 

Add these dependencies to your `pubspec.yaml`:
```yaml
dependencies:
  objectbox: ^1.4.1
  objectbox_flutter_libs: any
  # for ObjectBox Sync use this dependency instead:
  # objectbox_sync_flutter_libs: any

dev_dependencies:
  build_runner: ^2.0.0
  objectbox_generator: any
```

* Install the packages: `flutter pub get`
* **For iOS**: in the Flutter Runner Xcode project
  * increase the deployment target to at least iOS 11 and, 
  * under Architectures, replace `${ARCHS_STANDARD}` with `arm64` (or `$ARCHS_STANDARD_64_BIT`). See [FAQ](https://docs.objectbox.io/faq#on-which-platforms-does-objectbox-run) for details.
* **For sandboxed macOS apps**: specify an application group.
  Check all `macos/Runner/*.entitlements` files if they contain a `<dict>` section with correct group ID info. 
  Change the string value to the `DEVELOPMENT_TEAM` found in Xcode settings, plus an application-specific suffix, for example: 
  
  ```xml
  <key>com.apple.security.application-groups</key>
  <array>
    <string>FGDTDLOBXDJ.demo</string>
  </array>
  ```
  
  Next, in the app code, pass the same string when opening the Store, for example: `openStore(macosApplicationGroup: 'FGDTDLOBXDJ.demo')`.  
  Note: Pick a short group identifier; there's an internal limit in macOS that requires the complete string to be 
  19 characters or fewer.
* **For Sync + Android**: in `android/app/build.gradle` set `minSdkVersion 21` in section `android -> defaultConfig`. 
* In order to run Flutter unit tests locally on your machine, install the native ObjectBox library on 
  your host machine (same as you would if you developed for Dart native, as described in the next section):

  ```shell script
  bash <(curl -s https://raw.githubusercontent.com/objectbox/objectbox-dart/main/install.sh)
  ```

Continue with the [examples README](example/README.md) to learn how to create entities and use the ObjectBox API.

### Dart Native

Add these dependencies to your `pubspec.yaml`:
```yaml
dependencies:
  objectbox: ^1.4.1

dev_dependencies:
  build_runner: ^2.0.0
  objectbox_generator: any
```

* Install the packages: `dart pub get`
* Install [objectbox-c](https://github.com/objectbox/objectbox-c) system-wide (use "Git bash" on Windows):

  ```shell script
  bash <(curl -s https://raw.githubusercontent.com/objectbox/objectbox-dart/main/install.sh)
  ```
  
  To install ObjectBox Sync variant of the native library, pass `--sync` argument to the script:
  
  ```shell script
  bash <(curl -s https://raw.githubusercontent.com/objectbox/objectbox-dart/main/install.sh) --sync
  ```

Continue with the [examples README](example/README.md) to learn how to create entities and use the ObjectBox API.

## Database Performance Benchmarks

We tested across the four main database operations, CRUD (create, read, update, delete). Each test was run multiple times and executed 
manually outside of the measured time. Data preparation and evaluation were also done outside of the measured time.

![](https://raw.githubusercontent.com/objectbox/objectbox-dart/main/.github/benchmarks.png)

You can run these yourself using our [objectbox-dart-performance](https://github.com/objectbox/objectbox-dart-performance) Flutter benchmark app.

## Do you 💙 ObjectBox?
Your opinion matters to us! Please fill in this 2-minute [Anonymous Feedback Form](https://forms.gle/s2L1YH32nwjgs4s4A) to help us make ObjectBox better.

We strive to bring joy to Flutter developers and appreciate all kind of feedback, both positive and negative.
What do you love? What's amiss? Where do you struggle in everyday app development?

**We're looking forward to receiving your comments and requests:**

- Add [GitHub issues](https://github.com/objectbox/objectbox-dart/issues)
- Upvote issues you find important by hitting the 👍/+1 reaction button
- Drop us a line on Twitter via [@ObjectBox_io](https://twitter.com/ObjectBox_io/)
- ⭐ us, if you like what you see

Thank you! 🙏

Keep in touch: For general news on ObjectBox, [check our blog](https://objectbox.io/blog)!

## FAQ

See the [FAQ](https://docs.objectbox.io/faq) and [Troubleshooting](https://docs.objectbox.io/troubleshooting) pages.

## See also

* [Changelog](CHANGELOG.md)
* [Contribution guidelines](../CONTRIBUTING.md)

## License

```text
Copyright 2019-2022 ObjectBox Ltd. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
