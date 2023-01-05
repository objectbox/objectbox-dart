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
    <img src="https://img.shields.io/pub/v/objectbox.svg?label=pub.dev&logo=dart&style=flat-square" alt="pub.dev package">
  </a>
  <a href="https://github.com/objectbox/objectbox-dart/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/objectbox/objectbox-dart?logo=apache&style=flat-square" alt="Apache 2.0 license">
  </a>
  <a href="https://twitter.com/ObjectBox_io">
    <img src="https://img.shields.io/twitter/follow/objectbox_io?color=%20%2300aced&logo=twitter&style=flat-square" alt="Follow @ObjectBox_io">
  </a>
</p>

# Flutter database for fast Dart object persistence 💙

---

💙 Jobs: We're looking for a [Flutter Developer Relations Manager](https://objectbox.io/jobs/developer-relations-manager-evangelist-advocate/)! 💙

---

Database for Flutter / Dart - fast and simple. Persist local Dart objects with ease & speed, focus on the value your application provides.

```dart
// Annotate a Dart class to create a box
@Entity()
class Person {
  @Id() 
  int id;
  String name;

  Person({this.id = 0, required this.name});
}

// Put a new object into the box
var person = Person(name: "Joe Green");
final id = box.put(person);

// Get the object back from the box
person = box.get(id)!;

// Update the object
person.name = "Joe Black";
box.put(person);

// Query for objects
final query = box.query(Person_.name.equal("Joe Black"))
        .order(Person_.name).build();
final people = query.find();
query.close();

// Remove the object from the box
box.remove(person.id);
```
Ready? Continue with the **[Getting Started guide](https://docs.objectbox.io/getting-started)**.

## Table of Contents
- [Why use ObjectBox](#why-use-objectbox)
  - [Features](#features)
- [Getting Started](#getting-started)
- [How does ObjectBox compare to other solutions?](#how-does-objectbox-compare-to-other-solutions)
  - [Flutter Database Performance Benchmarks](#flutter-database-performance-benchmarks)
- [Do you 💙 ObjectBox?](#do-you--objectbox)
- [Contributing](#contributing)
- [Packages](#packages)
- [Other languages/bindings](#other-languagesbindings)
- [License](#license)

## Why use ObjectBox

ObjectBox Flutter database is a great option for storing Dart objects locally in your cross-platform
apps. It uses minimal CPU, memory and battery / power, which makes it a sustainable choice for mobile and IoT 
devices. Made for efficient data access, it is 10x faster than any alternative across all CRUD 
operations. See the [performance benchmarks](#flutter-database-performance-benchmarks) below.
No need to learn SQL, as our NoSQL database uses a pure Dart API that is easy to work with and can be 
integrated in minutes. Plus: We built a data synchronization solution that allows you to choose 
which objects to sync when and keep data easily and efficiently in sync across devices.

### Features

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

Continue with our **[Getting Started guide](https://docs.objectbox.io/getting-started)**.

It has resources and video tutorials on how to use ObjectBox in your Flutter or Dart app.

## How does ObjectBox compare to other solutions?

- ObjectBox is fast. Have a look at our benchmarks below, or test it for yourself
- It's a full NoSQL SQLite alternative with intuitive Dart APIs you'll love 💙
- It comes with an out-of-the-box [Data Sync](https://objectbox.io/sync/), making it an effective self-hosted Firebase alternative

### Flutter Database Performance Benchmarks

We tested across the four main database operations, CRUD (create, read, update, delete). Each test was run multiple times and executed  manually outside of the measured time. Data preparation and evaluation were done outside of the measured time. 

Here are the benchmarks for ObjectBox vs sqflite vs Hive 👇

![](https://raw.githubusercontent.com/objectbox/objectbox-dart/main/.github/benchmarks.png)

You can run these yourself using our [objectbox-dart-performance](https://github.com/objectbox/objectbox-dart-performance) Flutter benchmark app.

## Do you 💙 ObjectBox?

We strive to bring joy to Flutter developers and appreciate all kind of feedback, both positive and negative.

What do you love? What's amiss? Where do you struggle in everyday app development?
--> Please fill in this 2-minute [Anonymous Feedback Form](https://forms.gle/LvVjN6jfFHuivxZX6).

**We're looking forward to receiving your comments and requests:**

- Add [GitHub issues](https://github.com/objectbox/objectbox-dart/issues)
- Upvote issues you find important by hitting the 👍/+1 reaction button
- Fill in the [feedback form](https://forms.gle/s2L1YH32nwjgs4s4A) to help us improve our products
- Drop us a line on Twitter via [@ObjectBox_io](https://twitter.com/ObjectBox_io/)
- ⭐ us on GitHub, if you like what you see or give us a 👍 on [pub.dev](https://pub.dev/packages/objectbox)

Thank you! 🙏

Keep in touch: For general news on ObjectBox, [check our blog](https://objectbox.io/blog)!

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
