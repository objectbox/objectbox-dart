<p align="center">
  <img src="https://raw.githubusercontent.com/objectbox/objectbox-dart/main/.github/logo.png" width="400px">
</p>

# Flutter database for fast Dart object persistence 💙

[![pub package](https://img.shields.io/pub/v/objectbox.svg)](https://pub.dev/packages/objectbox)

Flutter database to store & sync objects across devices with sustainable offline-first approach

🏁 **High performance** on restricted devices, like IoT gateways, micro controllers, ECUs etc.\
🪂 **Resourceful** with minimal CPU, power and Memory usage for maximum flexibility and sustainability\
🔗 **Relations:** object links / relationships are built-in\
💻 **Multiplatform:** Linux, Windows, Android, iOS, macOS

🌱 **Scalable:** handling millions of objects resource-efficiently with ease\
💐 **Queries:** filter data as needed, even across relations\
🦮 **Statically typed:** compile time checks & optimizations\
📃 **Automatic schema migrations:** no update scripts needed

**And much more than just data persistence**\
👥 **[ObjectBox Sync](https://objectbox.io/sync/):** keeps data in sync between devices and servers\
🕒 **[ObjectBox TS](https://objectbox.io/time-series-database/):** time series extension for time based data

## Getting Started 

To start using ObjectBox in your Flutter/Dart app, head over to
* the [objectbox pub.dev page](https://pub.dev/packages/objectbox) or
* check out our [Getting Started guide](https://docs.objectbox.io/getting-started).

## Contributing 

If you'd like to contribute to the package as a developer, hack around, or just have a look at the code, you can 
clone/check out this repository and run `./tool/init.sh` to regenerate code and get you started. Make sure to have a
look at the [contribution guidelines](CONTRIBUTING.md) - all contributions are very welcome.

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

Other languages/bindings
------------------------
ObjectBox supports multiple platforms and languages: 

* [ObjectBox Java / Kotlin](https://github.com/objectbox/objectbox-java): runs on Android, desktop, and servers.
* [ObjectBox Swift](https://github.com/objectbox/objectbox-swift): build fast mobile apps for iOS (and macOS) 
* [ObjectBox Go](https://github.com/objectbox/objectbox-go): great for data-driven tools and embedded server applications 
* [ObjectBox C and C++](https://github.com/objectbox/objectbox-c): native speed with zero copy access to FlatBuffer objects


How I help ObjectBox?
---------------------------
We strive to bring joy to Flutter developers and appreciate all kinds feedback, both positive and negative.
What do you love? What's amiss? Where do you struggle in everyday app development?

**We're looking forward to receiving your comments and requests:**

- Add [GitHub issues](https://github.com/ObjectBox/objectbox-dart/issues) 
- Upvote issues you find important by hitting the 👍/+1 reaction button
- Drop us a line via [@ObjectBox_io](https://twitter.com/ObjectBox_io/)
- ⭐ us, if you like what you see 

Thank you! 🙏

Keep in touch: For general news on ObjectBox, [check our blog](https://objectbox.io/blog)!

## License

```text
Copyright 2019-2021 ObjectBox Ltd. All rights reserved.

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
