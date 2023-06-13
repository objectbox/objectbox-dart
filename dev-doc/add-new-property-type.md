# Adding a new property type

This is a checklist on how to add support for a new ObjectBox property type:

- Copy new enum from `objectbox_c.dart` to `OBXPropertyType`. May have to re-generate Dart bindings 
  first (see [dev-doc/updating-c-library.md](updating-c-library.md)).
- Add type to `PropertyType` enum.
- Add to `generator/integration-tests/basics` (both lib and other file).
- Add `OBXPropertyType` mappings in `propertyTypeToOBXPropertyType` and `obxPropertyTypeToString`.
- Update detection in `generator/lib/src/entity_resolver.dart`.
- Update code generator in `generator/lib/src/code_chunks.dart`.
  - May have to add new FlatBuffers reader in `objectbox/lib/src/native/bindings/flatbuffers_readers.dart`.
- Add put/get and query tests as needed to `objectbox_test`.
