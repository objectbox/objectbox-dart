This lib is based on official [FlatBuffers for Dart](https://github.com/google/flatbuffers), 
with `_buf/_buffer` backed by C memory (`ffi.Pointer<ffi.Uint8>`) to avoid copying.