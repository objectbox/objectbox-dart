/// The FlatBuffers implementation used by ObjectBox and its generated code.
///
/// On native platforms this is `package:flat_buffers` as-is. On web it is a
/// vendored copy with JavaScript-safe 64-bit integer handling, because
/// dart2js does not support `ByteData.get/setInt64` (see
/// `src/web/flatbuffers/`).
library;

export 'package:flat_buffers/flat_buffers.dart'
    if (dart.library.js_interop) 'src/web/flatbuffers/flat_buffers.dart';
