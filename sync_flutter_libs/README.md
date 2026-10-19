# ObjectBox database (with [Sync](https://objectbox.io/sync)) libraries for Flutter

[![pub package](https://img.shields.io/pub/v/objectbox_sync_flutter_libs.svg)](https://pub.dev/packages/objectbox_sync_flutter_libs)

This package provides the native ObjectBox database library, with the [Sync](https://objectbox.io/sync) 
client included, as a Flutter plugin for supported platforms.
Check the [Sync docs](https://sync.objectbox.io/) for more details.
You should add this package as a dependency when using [ObjectBox](https://pub.dev/packages/objectbox) with Flutter.

See package [objectbox](https://pub.dev/packages/objectbox) for more details and
information how to use it.

## Mesh Sync

To use [Mesh Sync](https://sync.objectbox.io/mesh-sync) (peer-to-peer) in a Flutter Android, iOS
or macOS app, also add the [objectbox_mesh_sync](https://pub.dev/packages/objectbox_mesh_sync)
package. It is a separate package as its network transport (based on Google Nearby Connections)
adds dependencies that apps not using Mesh Sync should not need to include.
