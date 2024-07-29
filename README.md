<p align="center">
  <picture>
    <img src="https://raw.githubusercontent.com/objectbox/objectbox-dart/main/.github/logo.png" alt="ObjectBox" width="400px">
  </picture>
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
    <img src="https://img.shields.io/pub/v/objectbox.svg?label=pub.dev&logo=dart&style=flat-square" alt="pub.dev package">
  </a>
  <a href="https://twitter.com/ObjectBox_io">
    <img src="https://img.shields.io/twitter/follow/objectbox_io?color=%20%2300aced&logo=twitter&style=flat-square" alt="Follow @ObjectBox_io">
  </a>
</p>

# Flutter database with vector support - easy to use & fast Dart object persistence, plus on-device vector search 💙



Very first on-device vector database for Flutter / Dart AI apps. Intuitive APIs, simply fast. 
Persist local Dart objects with ease & speed, efficiently manage vectors.

ObjectBox provides a store with boxes to put objects into:

```dart
// Annotate a Dart class to create a Box
@Entity()
class Person {
  @Id()
  int id;
  String firstName;
  String lastName;

  Person({this.id = 0, required this.firstName, required this.lastName});
}

final Store store = await openStore(directory: 'person-db');
final box = store.box<Person>();

var person = Person(firstName: 'Joe', lastName: 'Green');
final id = box.put(person); // Create

person = box.get(id)!;      // Read

person.lastName = 'Black';
box.put(person);            // Update

box.remove(person.id);      // Delete

final query = box           // Query
    .query(Person_.firstName.equals('Joe') & Person_.lastName.startsWith('B'))
    .build();
final List<Person> people = query.find();
query.close();
```
Ready? Continue with the ➡️ **[Getting Started guide](https://docs.objectbox.io/getting-started)**.

## Why use ObjectBox

ObjectBox Flutter database is an excellent choice for storing Dart objects in cross-platform
applications and the only on-device database that offers you vector support for your on-device AI apps.
Designed for high performance, the ObjectBox Flutter database is excellent for mobile
and IoT devices. ObjectBox consumes minimal CPU, memory, and battery, ensuring that your software is
not only efficient but also sustainable. By storing data locally on the device, ObjectBox allows you
to cut cloud costs and create an app that does not require a connection. Get started with our
intuitive native Dart API in minutes, without the hassle of SQL.
Plus: We built a data synchronization solution that allows you to keep data in sync across devices
and servers, both online and offline.

### Features
🏁 **Very first [on-device vector database](https://docs.objectbox.io/on-device-ann-vector-search)** - for AI apps that work any place.\

🏁 **High performance** - superfast response rates enabling real-time applications.\
🪂 **ACID compliant** - Atomic, Consistent, Isolated, Durable.\
💻 **Multiplatform** - Android, iOS, macOS, Linux, Windows, any POSIX-system.\
🌱 **Scalable** - grows with your app, handling millions of objects with ease.\
💚 **Sustainable** - frugal on CPU, Memory and battery / power use, reducing CO2 emmissions.

🔗 **[Relations](https://docs.objectbox.io/relations)** - object links / relationships are built-in.\
💐 **[Queries](https://docs.objectbox.io/queries)** - filter data as needed, even across relations.\
🦮 **Statically typed** - compile time checks & optimizations.\
📃 **Schema migration** - change your model with confidence.

Oh, and there is one more thing...

😮 [**Data Sync**](https://objectbox.io/sync/) - keeps data in sync offline or online, between devices and servers.


## Getting Started

Continue with our ➡️ **[Getting Started guide](https://docs.objectbox.io/getting-started)**. It has resources and video tutorials on how to use ObjectBox in your Flutter or Dart app.

## How does ObjectBox compare to other solutions?

- ObjectBox is fast. Have a look at our benchmarks below, or test it for yourself
- It's a full NoSQL SQLite alternative with intuitive Dart APIs you'll love 💙
- It comes with an out-of-the-box [Data Sync](https://objectbox.io/sync/), making it an effective self-hosted Firebase alternative

### Flutter Database Performance Benchmarks

We tested across the four main database operations, CRUD (create, read, update, delete). Each test was run multiple times and executed  manually outside of the measured time. Data preparation and evaluation were done outside of the measured time. 

Here are the benchmarks for ObjectBox vs sqflite vs Hive 👇

![](https://raw.githubusercontent.com/objectbox/objectbox-dart/main/.github/benchmarks.png)

You can run these yourself using our [objectbox-dart-performance](https://github.com/objectbox/objectbox-dart-performance) Flutter benchmark app.

## How do you 💙 ObjectBox?

**We're looking forward to receiving your comments and requests:**

- Add [GitHub issues](https://github.com/objectbox/objectbox-dart/issues)
- Upvote issues you find important by hitting the 👍/+1 reaction button
- Fill in the [anonymous feedback form](https://forms.gle/s2L1YH32nwjgs4s4A) to help us improve our products
- Drop us a line on Twitter via [@ObjectBox_io](https://twitter.com/ObjectBox_io/)
- ⭐ us on GitHub, if you like what you see or give us a 👍 on [pub.dev](https://pub.dev/packages/objectbox)

Thank you! 🙏

For general news on ObjectBox, [check our blog](https://objectbox.io/blog)!

## Contributing

Do you want to check out the ObjectBox code itself? E.g. see in action, run tests, or even contribute code?
Great! Clone/check out this repository and run this to generate code and get you started quickly:

    ./tool/init.sh

Also, make sure to have a look at the [contribution guidelines](CONTRIBUTING.md) - we are looking forward to your contribution.

## Packages

This repository holds all ObjectBox Dart/Flutter packages as separate directories:

* [objectbox](objectbox) - main library code
* [objectbox_generator](generator) - code generator
* [objectbox_flutter_libs](flutter_libs) - core binary library dependency for Flutter (Android/iOS) - no dart/flutter code
* [objectbox_sync_flutter_libs](sync_flutter_libs) - core binary library dependency with [**ObjectBox Sync**](https://objectbox.io/sync/) enabled
* [benchmark](benchmark) - used internally to microbenchmark and compare various implementations during development of objectbox-dart

There's also a separate repository benchmarking objectbox (and other databases) in Flutter: 
[objectbox-dart-performance](https://github.com/objectbox/objectbox-dart-performance). And another one testing and 
comparing the performance of our FlatBuffers fork vs the upstream version: [flatbuffers-benchmark](https://github.com/objectbox/flatbuffers-benchmark).

## Other languages/bindings

ObjectBox supports multiple platforms and languages: 

* [Java Database](https://github.com/objectbox/objectbox-java) (+ Kotlin): runs on Android, desktop, and servers.
* [Swift Database](https://github.com/objectbox/objectbox-swift): build fast mobile apps for iOS and macOS.
* [Go Database](https://github.com/objectbox/objectbox-go): great for data-driven tools and embedded server applications.
* [C / C++ Database](https://github.com/objectbox/objectbox-c): native speed with zero copy access to FlatBuffer objects.


## License

```text
Copyright 2019-2024 ObjectBox Ltd. All rights reserved.

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

Note that this license applies to the code in this repository only.
See our website on details about all [licenses for ObjectBox components](https://objectbox.io/faq/#license-pricing).
