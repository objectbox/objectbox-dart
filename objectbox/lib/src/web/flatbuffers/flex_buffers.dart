// Vendored from package:flat_buffers 25.9.23 (Apache-2.0, Copyright Google
// Inc.) for the ObjectBox web implementation, with one change: all 64-bit
// integer ByteData accessors are replaced with JavaScript-safe versions built
// from two 32-bit halves, because dart2js does not support
// ByteData.get/setInt64/Uint64. Values keep full precision up to 2^53 (all
// JavaScript numbers are doubles). Used via the conditional export in
// lib/flatbuffers.dart; native platforms use the real package.
// ignore_for_file: type=lint
export 'src/builder.dart';
export 'src/reference.dart';
