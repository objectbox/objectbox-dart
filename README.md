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

# Flutter database for fast Dart object persistence 💙

Flutter database to store & sync objects across devices with a sustainable offline-first approach

🏁 **High performance** on mobile and restricted devices, like IoT gateways, microcontrollers, ECUs etc.\
🪂 **Resourceful** with minimal CPU, power and memory usage for maximum flexibility and sustainability\
🔗 **Relations:** object links / relationships are built-in\
💻 **Multiplatform:** Linux, Windows, Android, iOS, macOS

🌱 **Scalable:** handling millions of objects resource-efficiently with ease\
💐 **Queries:** filter data as needed, even across relations\
🦮 **Statically typed:** compile time checks & optimizations\
📃 **Automatic schema migrations:** no update scripts needed

**And much more than just data persistence**\
👥 **[ObjectBox Sync](https://objectbox.io/sync/):** keeps data in sync between devices and servers\
🕒 **[ObjectBox TS](https://objectbox.io/time-series-database/):** time series extension for time based data

## Getting Started (in your App)

To start using ObjectBox in your Flutter/Dart app, head over to

* the [ObjectBox pub.dev page](https://pub.dev/packages/objectbox) or
* check out our [Getting Started Guide](https://docs.objectbox.io/getting-started).

## Getting Started with this Repository 

Do you want to check out the ObjectBox code itself? E.g. see in action, run tests, or even contribute code?
Great! Clone/check out this repository and run this to generate code and get you started quickly:

    ./tool/init.sh

Also, make sure to have a look at the [contribution guidelines](CONTRIBUTING.md) - we are looking forward to your contribution.

## Do you 💙 ObjectBox?
Your opinion matters to us! Please fill in this 2-minute [Anonymous Feedback Form](https://forms.gle/LvVjN6jfFHuivxZX6).

We strive to bring joy to Flutter developers and appreciate all kind of feedback, both positive and negative.
What do you love? What's amiss? Where do you struggle in everyday app development?

**We're looking forward to receiving your comments and requests:**

- Add [GitHub issues](https://github.com/objectbox/objectbox-dart/issues) 
- Upvote issues you find important by hitting the 👍/+1 reaction button
- Drop us a line on Twitter via [@ObjectBox_io](https://twitter.com/ObjectBox_io/)
- ⭐ us, if you like what you see 

Thank you! 🙏

Keep in touch: For general news on ObjectBox, [check our blog](https://objectbox.io/blog)!

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

* [ObjectBox Java / Kotlin](https://github.com/objectbox/objectbox-java): runs on Android, desktop, and servers.
* [ObjectBox Swift](https://github.com/objectbox/objectbox-swift): build fast mobile apps for iOS and macOS 
* [ObjectBox Go](https://github.com/objectbox/objectbox-go): great for data-driven tools and embedded server applications 
* [ObjectBox C and C++](https://github.com/objectbox/objectbox-c): native speed with zero copy access to FlatBuffer objects


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
