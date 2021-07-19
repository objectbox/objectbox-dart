![ObjectBox logo](https://raw.githubusercontent.com/objectbox/objectbox-java/master/logo.png)

ObjectBox Dart & Flutter
==========================

ObjectBox is a super-fast database storing Dart objects locally.

* 🏁 **High performance** - improving response rates and enabling real-time applications.
* 🪂 **ACID compliance** - Atomic, Consistent, Isolated, Durable.
* 🔗 **Relations** - object links / relationships are built-in.
* 🌱 **Scalable** - grows with your app, handling millions of objects with ease.
* 💐 **Queries** - filter data as needed, even across relations.
* 🦮 **Statically typed** - compile time checks & optimizations.
* 💻 **Multiplatform** - Android, iOS, macOS, Linux, Windows.
* 📃 **Schema migration** - change your model with confidence.
* 👥 [**ObjectBox Sync**](https://objectbox.io/sync/) - keeps data in sync offline or online, between devices and servers.

## Sneak peek

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

Head over to [docs](https://docs.objectbox.io/getting-started) and [examples](example/README.md) for more.

Getting started
---------------

Add the following dependencies to start using ObjectBox and code generator.

### Flutter 

```yaml
dependencies:
  objectbox: ^1.1.1
  objectbox_flutter_libs: any

dev_dependencies:
  build_runner: ^1.0.0
  objectbox_generator: any
```

* Install the packages: `flutter pub get`
* XCode/iOS only: increase the deployment target to iOS 11 and, under Architectures, replace `${ARCHS_STANDARD}` with `arm64` (or `$ARCHS_STANDARD_64_BIT`). See [FAQ](#faq) for details.
* If targeting macOS (creating sandboxed macOS apps): you need to specify an application group.
  Check all `macos/Runner/*.entitlements` files if they contain a `<dict>` section with correct group ID info. 
  Change the string value to the `DEVELOPMENT_TEAM` you can find in your Xcode settings, plus an application-specific suffix, for example: 
  
  ```xml
  <key>com.apple.security.application-groups</key>
  <array>
    <string>FGDTDLOBXDJ.demo</string>
  </array>
  ```
  
  Next, in your app code, pass the same string when opening the Store, for example: `openStore(macosApplicationGroup: 'FGDTDLOBXDJ.demo')`.  
  Note: Pick a short group identifier; there's an internal limit in macOS that requires the complete string to be 
  19 characters or fewer.
* Sync + Android only: in your `android/app/build.gradle` set `minSdkVersion 21` in section `android -> defaultConfig`. 
* In order to run Flutter unit tests locally on your machine, you'll need to install the native ObjectBox library on 
  your host machine (same as you would if you developed for Dart native, as described in the next section):

  ```shell script
  bash <(curl -s https://raw.githubusercontent.com/objectbox/objectbox-dart/main/install.sh)
  ```

### Dart Native

```yaml
dependencies:
  objectbox: ^1.1.1

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

Help wanted
-----------

ObjectBox Dart is open to contributions and feedback on [GitHub](https://github.com/objectbox/objectbox-dart/issues).
Either comment on an existing issue or open a new one. For example, if you experience errors or if you have ideas how to
improve the API. If you'd like to contribute some code: PRs are more than welcome! The ObjectBox team will try its best 
to guide you and answer questions.

FAQ
---

_**Q: After adding ObjectBox, the size of the APK increased significantly. Why is that?**_  
**A: This is caused by ObjectBox following
the [official Android recommendations](https://developer.android.com/topic/performance/reduce-apk-size#extract-false)
for library compression settings**. By default, Flutter apps created from the template have the compression enabled,
opposite to the recommendation. The setting to disable library compression affects all native libraries in your app, not
just ObjectBox - with Flutter native libraries now taking up the large portion of the increased APK size. ObjectBox
library adds about 5.8 MiB uncompressed, and Flutter framework libs increase the uncompressed size by 18.4 MiB.  
_Q: Should I be worried about the size increase of uncompressed libraries?_  
A: No, not really. Packaging uncompressed `.so` files is actually better for users. It uses less storage on device as it
avoids copying .so files from the APK to the filesystem during installation and has the added benefit of making updates
of your app smaller. For more information about the sizes, see the following table created with 
ObjectBox v0.14.0 and Flutter v2.0.5 release builds (using the [recommended](https://flutter.dev/docs/deployment/android#build-an-apk)
`flutter build apk --split-per-abi` to build APKs for each ABI):

| Release                                   | without ObjectBox |            with ObjectBox |    difference |
| ----------------------------------------- | ----------------: | ------------------------: | ------------: |
| APK (default compressed, arm64-v8a)       |           5.5 MiB |       6.0 MiB<sup>1</sup> |      +0.5 MiB |
| APK (uncompressed, arm64-v8a)<sup>2</sup> |          12.0 MiB |                  13.5 MiB |  **+1.5 MiB** |
| Fat APK (uncompressed, all ABIs)          |          33.8 MiB |                  39.6 MiB |      +5.8 MiB |

<sup>1</sup> Requires turning compression back on: in the `<application>` tag in `android/app/src/main/AndroidManifest.xml` add
```
android:extractNativeLibs="true"
tools:replace="android:extractNativeLibs"
```
to override the ObjectBox settings.

<sup>2</sup> This is also about the size an APK generated by Google Play would be when uploading an App Bundle (`flutter build appbundle`).

_**Q: Flutter iOS builds for armv7 fail with "ObjectBox does not contain that architecture", does it not support 32-bit devices?**_  
**A: No, only 64-bit iOS devices are supported.** When ObjectBox was first released for iOS all the latest iOS devices had 64-bit support,
so we decided to not ship armv7 support. To resolve the build error, in your XCode project
look under Architectures and replace `${ARCHS_STANDARD)` with `arm64` (or `$ARCHS_STANDARD_64_BIT`).

See also
---------

* [Changelog](CHANGELOG.md)
* [Contribution guidelines](../CONTRIBUTING.md)

License
-------

```text
Copyright 2020 ObjectBox Ltd. All rights reserved.

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
