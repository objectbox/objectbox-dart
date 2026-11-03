#!/usr/bin/env bash
. "$(dirname "$0")"/common.sh

if [[ "$#" -ne "1" ]]; then
  echo "usage: $0 <version>"
  echo "e.g. $0 3.0.0"
  exit 1
fi

version=$1

echo "Setting ObjectBox Swift version: $version"

# Regular expressions match any version string ending with a single quote ('),
# such as 1.2.3' or 1.2.3-beta.1'

# CocoaPods podspec files
versionExpr="s/dependency 'ObjectBox', '[^\']*'/dependency 'ObjectBox', '${version}'/g"
update flutter_libs/ios/objectbox_flutter_libs.podspec "${versionExpr}"
update flutter_libs/macos/objectbox_flutter_libs.podspec "${versionExpr}"

versionExpr="s/dependency 'ObjectBox', '[^\']*'/dependency 'ObjectBox', '${version}-sync'/g"
update sync_flutter_libs/ios/objectbox_sync_flutter_libs.podspec "${versionExpr}"
update sync_flutter_libs/macos/objectbox_sync_flutter_libs.podspec "${versionExpr}"

# Swift Package files
versionExpr="s/objectbox-swift-spm.git\", exact: \"[^\"]*\"/objectbox-swift-spm.git\", exact: \"${version}\"/g"
update flutter_libs/ios/objectbox_flutter_libs/Package.swift "${versionExpr}"
update flutter_libs/macos/objectbox_flutter_libs/Package.swift "${versionExpr}"
echo "⚠️ Currently, doesn't update the Package.swift and Package@swift-5.9.swift files of sync_flutter_libs and objectbox_mesh_sync as the Swift Package is pinned by revision there, see notes in files! Update all of them to the same revision."
#update sync_flutter_libs/ios/objectbox_sync_flutter_libs/Package.swift "${versionExpr}"
#update sync_flutter_libs/macos/objectbox_sync_flutter_libs/Package.swift "${versionExpr}"
#update objectbox_mesh_sync/ios/objectbox_mesh_sync/Package.swift "${versionExpr}"
#update objectbox_mesh_sync/macos/objectbox_mesh_sync/Package.swift "${versionExpr}"
## Manifests used by older Swift tools (without the Mesh Sync trait)
#update objectbox_mesh_sync/ios/objectbox_mesh_sync/Package@swift-5.9.swift "${versionExpr}"
#update objectbox_mesh_sync/macos/objectbox_mesh_sync/Package@swift-5.9.swift "${versionExpr}"
