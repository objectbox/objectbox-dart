#!/usr/bin/env bash
. "$(dirname "$0")"/common.sh

# Downloads the C library source files of a specific release from GitHub,
# copies the header files, makes some required modifications
# and runs the ffigen binding generator on them.
#
# Options:
#   --skip-download   Skip downloading and extracting the C library source files.
#                     Use this when you have already downloaded the files or
#                     manually updated a header in objectbox/lib/src/native/bindings/.
#                     The script will still apply required modifications and
#                     regenerate the Dart FFI bindings with ffigen.
#   --clang-fix       Pass clang's own resource directory to ffigen via --compiler-opts.
#                     Use this if ffigen produces wrong types (e.g. ffi.Int instead of
#                     ffi.Bool or ffi.Size), which happens when clang cannot find its
#                     builtin headers (stdbool.h, stddef.h) during parsing.

skipDownload=false
clangFix=false
for arg in "$@"; do
    case "${arg}" in
        --skip-download) skipDownload=true ;;
        --clang-fix) clangFix=true ;;
        *) echo "Unknown argument: ${arg}"; exit 1 ;;
    esac
done

cLibVersion=5.3.1

if [ "${skipDownload}" = false ]; then
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
else
    echo "Skipping download of C library"
fi

# Replace `const void*` by `const uint8_t*` in all objectbox*.h files
# (see ffigen note in ../objectbox/pubspec.yaml).
echo
echo "Replacing 'const void*' by 'const uint8_t*'..."
replaceVoidExpr="s/const void\*/const uint8_t*/g"
update objectbox/lib/src/native/bindings/objectbox.h "${replaceVoidExpr}"
update objectbox/lib/src/native/bindings/objectbox-dart.h "${replaceVoidExpr}"
update objectbox/lib/src/native/bindings/objectbox-sync.h "${replaceVoidExpr}"

# This requires LLVM libraries
# (see ffigen docs https://pub.dev/packages/ffigen#requirements
# and the ffigen section in ../objectbox/pubspec.yaml).
echo
echo "Generating bindings with ffigen (requires LLVM libraries)..."

ffigenCompilerOpts=""
if [ "${clangFix}" = true ]; then
    # Pass clang's own resource directory so that builtin headers (stdbool.h, stddef.h, etc.) are found.
    # Without this, ffigen/libclang may fail to locate them,
    # causing bool -> ffi.Int and size_t -> ffi.Int instead of the correct ffi.Bool / ffi.Size mappings.
    clangResourceDir=$(clang -print-resource-dir 2>/dev/null)
    if [ -n "${clangResourceDir}" ]; then
        echo "Using clang resource dir: ${clangResourceDir}"
        ffigenCompilerOpts="--compiler-opts \"-I${clangResourceDir}/include\""
    else
        echo "Warning: could not determine clang resource dir via 'clang -print-resource-dir'"
    fi
fi

cd objectbox
eval dart run ffigen ${ffigenCompilerOpts}
