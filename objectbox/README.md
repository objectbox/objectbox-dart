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

# Flutter database for Dart-native objects 💙

ObjectBox Flutter database is a great option for storing Dart objects in your cross-platform apps. Designed for 
high performance, the ObjectBox Flutter database is ideal or mobile and IoT devices. ObjectBox uses minimal CPU, 
memory and battery, making your app not only effective, but also sustainable. By storing data locally on device, 
ObjectBox helps you cut your cloud costs down and make an app that doesn't depend connection. Get started with
our intuitive native Dart API in minutes, without the hassle of SQL.
Plus: We built a data synchronization solution that allows you to keep data in sync across devices and servers,
both online and offline.

## Features

🏁 **Super fast** - 10X faster than SQLite - see the [performance benchmarks](#flutter-database-performance-benchmarks).\
🪂 **ACID compliant** - Atomic, Consistent, Isolated, Durable.\
💻 **Cross-platform** - Android, iOS, macOS, Linux, Windows.\
🌱 **Scalable** - grows with your app, handling millions of objects with ease.

🎯 **NoSQL database** - no rows or columns, only pure Dart objects.\
🔗 **[Relations](https://docs.objectbox.io/relations)** - object links / relationships are built-in.\
💐 **[Queries](https://docs.objectbox.io/queries)** - filter data as needed, even across relations.\
📃 **Schema migration** - simply change your model, we handle the rest.

Oh, and there is one more thing...

😮 [**Data Sync**](https://objectbox.io/sync/) - sync only when and where needed.

## On this page
- [Sneak peek](#sneak-peek---persist-dart-objects-with-objectbox)
- [Getting Started](#getting-started)
  - [Flutter](#flutter)
  - [Dart Native](#dart-native)
- [Flutter Database Performance Benchmarks](#flutter-database-performance-benchmarks)
- [Do you 💙 ObjectBox?](#do-you--objectbox)
- [FAQ](#faq)
- [See also](#see-also)
- [License](#license)

---

## Sneak peek - persist Dart objects with ObjectBox

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

## Getting Started

Read the **[Getting Started guide](https://docs.objectbox.io/getting-started)**. 

It has resources and video tutorials on how to use ObjectBox in your Flutter or Dart app.

We also have some video tutorials, each featuring a different example app: 
- [Shop order app](https://youtu.be/AxYbdriXKI8)
- [Restaurant: chef and order apps](https://youtu.be/r9Lc2r22KBk)
- [Task-list app (in Spanish)](https://youtu.be/osUq6B92-BY)
- [Inventory Management](https://www.youtube.com/watch?v=BBlr8F8m9lo)

## Flutter Database Performance Benchmarks

We tested across the four main database operations, CRUD (create, read, update, delete). Each test was run multiple times and executed  manually outside of the measured time. Data preparation and evaluation were also done outside of the measured time. 

Here are the benchmarks for ObjectBox vs sqflite vs Hive 👇

![](https://raw.githubusercontent.com/objectbox/objectbox-dart/main/.github/benchmarks.png)

You can run these yourself using our [objectbox-dart-performance](https://github.com/objectbox/objectbox-dart-performance) Flutter benchmark app.

## Do you 💙 ObjectBox?

We strive to bring joy to Flutter developers and appreciate any feedback
--> Please fill in this 2-minute [Anonymous Feedback Form](https://forms.gle/LvVjN6jfFHuivxZX6).

**We ❤️ you & are looking forward to your comments and ideas:**

- Add [GitHub issues](https://github.com/objectbox/objectbox-dart/issues)
- Upvote issues you find important by hitting the 👍/+1 reaction button
- Fill in the [feedback form](https://forms.gle/s2L1YH32nwjgs4s4A) to help us improve our products
- Drop us a line on Twitter via [@ObjectBox_io](https://twitter.com/ObjectBox_io/)
- ⭐ us on GitHub, if you like what you see or give us a 👍 on [pub.dev](https://pub.dev/packages/objectbox)

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
