#!/usr/bin/env bash
. "$(dirname "$0")"/common.sh

# Downloads the C library source files of a specific release from GitHub,
# copies the header files, makes some required modifications
# and runs the ffigen binding generator on them.

cLibVersion=4.0.0
echo "Downloading C library source files from GitHub..."

# Note: the release archives do not contain objectbox-dart.h, so get the full sources.
archiveExt="zip"
downloadUrl="https://github.com/objectbox/objectbox-c/archive/refs/tags/v${cLibVersion}.${archiveExt}"
echo "Download URL: ${downloadUrl}"

targetDir="objectbox/download"
archiveFile="${targetDir}/objectbox-c-${cLibVersion}.${archiveExt}"
mkdir -p "$(dirname "${archiveFile}")"

# Support both curl and wget because their availability is platform dependent
if [ -x "$(command -v curl)" ]; then
    curl --location --fail --output "${archiveFile}" "${downloadUrl}"
else
    wget --no-verbose --output-document="${archiveFile}" "${downloadUrl}"
fi

if [[ ! -s ${archiveFile} ]]; then
    echo "Error: download failed (file ${archiveFile} does not exist or is empty)"
    exit 1
fi

echo
echo "Downloaded:"
du -h "${archiveFile}"

echo
echo "Extracting into ${targetDir}..."
unzip "${archiveFile}" -d "${targetDir}"

headerBuildDir="objectbox/lib/src/native/bindings"
echo
echo "Copying to ${headerBuildDir}..."
mkdir -p "${headerBuildDir}"
cp "${targetDir}/objectbox-c-${cLibVersion}"/include/*.h "${headerBuildDir}"
ls -l "${headerBuildDir}"

# Replace `const void*` by `const uint8_t*` in all objectbox*.h files
# (see ffigen note in ../objectbox/pubspec.yaml).
echo
echo "Replacing 'const void*' by 'const uint8_t*'..."
replaceVoidExpr="s/const void\*/const uint8_t*/g"
update objectbox/lib/src/native/bindings/objectbox.h "${replaceVoidExpr}"
update objectbox/lib/src/native/bindings/objectbox-dart.h "${replaceVoidExpr}"
update objectbox/lib/src/native/bindings/objectbox-sync.h "${replaceVoidExpr}"

# This requires LLVM libraries
# (see ffigen docs https://pub.dev/packages/ffigen#installing-llvm
# and the ffigen section in ../objectbox/pubspec.yaml).
echo
echo "Generating bindings with ffigen (requires LLVM libraries)..."
cd objectbox
dart run ffigen
