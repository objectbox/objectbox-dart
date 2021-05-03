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

// Note: in Flutter you also need to specify a directory, see examples.
final store = Store(getObjectBoxModel());
final box = store.box<Person>();

var person = Person(firstName: 'Joe', lastName: 'Green');

final id = box.put(person);  // Create

person = box.get(id)!;        // Read

person.lastName = "Black";
box.put(person);             // Update

box.remove(person.id);       // Delete

// find all people whose name start with letter 'J'
final query = box.query(Person_.firstName.startsWith('J')).build();
final people = query.find();  // find() returns List<Person>
```

Head over to [examples](objectbox/example/README.md) for more.

Getting started
---------------

Add the following dependencies to start using ObjectBox and code generator.

### Flutter mobile apps

```yaml
dependencies:
  objectbox: ^0.14.0
  objectbox_flutter_libs: any

dev_dependencies:
  build_runner: ^1.0.0
  objectbox_generator: any
```

* Install the packages: `flutter pub get`
* XCode/iOS: under Architectures replace `${ARCHS_STANDARD)` with `arm64` (or `$ARCHS_STANDARD_64_BIT`). See [FAQ](#faq) for details.

### Dart CLI apps or Flutter desktop apps

```yaml
dependencies:
  objectbox: ^0.14.0

dev_dependencies:
  build_runner: ^1.0.0
  objectbox_generator: any
```

* Install the packages: `(flutter|dart) pub get`
* Install [objectbox-c](https://github.com/objectbox/objectbox-c) system-wide (use "Git bash" on Windows):

  ```shell script
  bash <(curl -s https://raw.githubusercontent.com/objectbox/objectbox-dart/main/install.sh)
  ```
  
  To install ObjectBox Sync variant of the native library, pass `--sync` argument to the script:
  
  ```shell script
  bash <(curl -s https://raw.githubusercontent.com/objectbox/objectbox-dart/main/install.sh) --sync
  ```

* macOS: dart might later complain that it cannot find the `libobjectbox.dylib`. You probably have to unsign the `dart`
  binary - see [this dart issue](https://github.com/dart-lang/sdk/issues/38314#issuecomment-534102841) for details.

* Windows: copy the downloaded `lib/objectbox.dll` to `C:\Windows\System32\` (requires admin privileges).

Help wanted
-----------

ObjectBox Dart is still not on par with other language bindings where ObjectBox is available.
To bring all the missing features to Dart, we're asking the community to help out. PRs are more than welcome!
The ObjectBox team will try its best to guide you and answer questions.

### Feedback

Also, please let us know your feedback GitHub issues, either comment on an existing one or open a new one.
For example, if you experience errors or if you have ideas for how to improve the API.
Thanks!

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
A: No, not really - creating uncompressed APK is actually better for users - uses less storage on device and allows for
smaller updates. Also, App bundles (`.aab`) are not affected and actually show the real size ObjectBox adds. For more
information about the sizes, see the following table created with ObjectBox v0.14.0 and Flutter v2.0.5 release builds
(`flutter build apk` and `flutter build appbundle`):

| Release           | without ObjectBox | with ObjectBox |    Difference |
| ----------------- | ----------------: | -------------: | ------------: | 
| .apk              |         15.39 MiB |      39.60 MiB |    +24.21 MiB |
| .apk uncompressed |         33.81 MiB |      39.60 MiB |     +5.79 MiB |
| .aab (App bundle) |         15.39 MiB |      17.58 MiB | **+2.19 MiB** |

_**Q: Flutter iOS builds for armv7 fail with "ObjectBox does not contain that architecture", does it not support 32-bit devices?**_  
**A: No, only 64-bit iOS devices are supported.** When ObjectBox was first released for iOS all the latest iOS devices had 64-bit support,
so we decided to not ship armv7 support. To resolve the build error, in your XCode project
look under Architectures and replace `${ARCHS_STANDARD)` with `arm64` (or `$ARCHS_STANDARD_64_BIT`).

See also
---------

* [Changelog](objectbox/CHANGELOG.md)
* [Contribution guidelines](CONTRIBUTING.md)

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
