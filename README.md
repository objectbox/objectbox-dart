![ObjectBox logo](https://raw.githubusercontent.com/objectbox/objectbox-java/master/logo.png)

# Flutter database for Dart-native object persistence 💙

[![pub package](https://img.shields.io/pub/v/objectbox.svg)](https://pub.dev/packages/objectbox)

ObjectBox is a super-fast Flutter database storing Dart objects locally

* 🏁 **High performance** - improving response rates and enabling real-time applications.
* 🪂 **ACID compliance** - Atomic, Consistent, Isolated, Durable.
* 🔗 **Relations** - object links / relationships are built-in.
* 🌱 **Scalable** - grows with your app, handling millions of objects with ease.
* 💐 **Queries** - filter data as needed, even across relations.
* 🦮 **Statically typed** - compile time checks & optimizations.
* 💻 **Multiplatform** - Android, iOS, macOS, Linux, Windows.
* 📃 **Schema migration** - change your model with confidence.
* 👥 [**Out-of-the-box Data Sync**](https://objectbox.io/sync/) - keeps data in sync offline or online, between devices and servers.

## Getting Started

To start using ObjectBox in your Flutter/Dart app, head over to
* the [objectbox pub.dev page](https://pub.dev/packages/objectbox) or
* check out our [Getting Started guide](https://docs.objectbox.io/getting-started).

## Contributing

If you'd like to contribute to the package as a developer, hack around, or just have a look at the code, you can 
clone/check out this repository and run `./tool/init.sh` to regenerate code and get you started. Make sure to have a
look at the [contribution guidelines](CONTRIBUTING.md) - all contributions are very welcome.

## Benchmarks


### Packages

This repository holds all ObjectBox Dart/Flutter packages as separate directories:

* [objectbox](objectbox) - main library code
* [objectbox_generator](generator) - code generator
* [objectbox_flutter_libs](flutter_libs) - core binary library dependency for Flutter (Android/iOS) - no dart/flutter code
* [objectbox_sync_flutter_libs](sync_flutter_libs) - core binary library dependency with [**ObjectBox Sync**](https://objectbox.io/sync/) enabled
* [benchmark](benchmark) - used internally to microbenchmark and compare various implementations during development of objectbox-dart

There's also a separate repository benchmarking objectbox (and other databases) in Flutter: 
[objectbox-dart-performance](https://github.com/objectbox/objectbox-dart-performance). And another one testing and 
comparing the performance of our FlatBuffers fork vs the upstream version: [flatbuffers-benchmark](https://github.com/objectbox/flatbuffers-benchmark).

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
