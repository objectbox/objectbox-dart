// Note: the enums in this file are copied from native/bindings/objectbox_c.dart
// to avoid package:ffi import which would break compatibility with web.

// ignore_for_file: public_member_api_docs, constant_identifier_names

import '../annotations.dart';

/// Maps [OBXPropertyType] to its string representation (name).
String obxPropertyTypeToString(int type) {
  switch (type) {
    case OBXPropertyType.Bool:
      return 'bool';
    case OBXPropertyType.Byte:
      return 'byte';
    case OBXPropertyType.Short:
      return 'short';
    case OBXPropertyType.Char:
      return 'char';
    case OBXPropertyType.Int:
      return 'int';
    case OBXPropertyType.Long:
      return 'long';
    case OBXPropertyType.Float:
      return 'float';
    case OBXPropertyType.Double:
      return 'double';
    case OBXPropertyType.String:
      return 'string';
    case OBXPropertyType.Date:
      return 'date';
    case OBXPropertyType.Relation:
      return 'relation';
    case OBXPropertyType.DateNano:
      return 'dateNano';
    case OBXPropertyType.ByteVector:
      return 'byteVector';
    case OBXPropertyType.CharVector:
      return 'charVector';
    case OBXPropertyType.ShortVector:
      return 'shortVector';
    case OBXPropertyType.IntVector:
      return 'intVector';
    case OBXPropertyType.LongVector:
      return 'longVector';
    case OBXPropertyType.FloatVector:
      return 'floatVector';
    case OBXPropertyType.DoubleVector:
      return 'doubleVector';
    case OBXPropertyType.StringVector:
      return 'stringVector';
  }

  throw ArgumentError.value(type, 'type', 'Invalid OBXPropertyType');
}

int propertyTypeToOBXPropertyType(PropertyType type) {
  switch (type) {
    case PropertyType.byte:
      return OBXPropertyType.Byte;
    case PropertyType.short:
      return OBXPropertyType.Short;
    case PropertyType.char:
      return OBXPropertyType.Char;
    case PropertyType.int:
      return OBXPropertyType.Int;
    case PropertyType.float:
      return OBXPropertyType.Float;
    case PropertyType.date:
      return OBXPropertyType.Date;
    case PropertyType.dateNano:
      return OBXPropertyType.DateNano;
    case PropertyType.byteVector:
      return OBXPropertyType.ByteVector;
    case PropertyType.charVector:
      return OBXPropertyType.CharVector;
    case PropertyType.shortVector:
      return OBXPropertyType.ShortVector;
    case PropertyType.intVector:
      return OBXPropertyType.IntVector;
    case PropertyType.floatVector:
      return OBXPropertyType.FloatVector;
    default:
      throw ArgumentError.value(type, 'type', 'Invalid PropertyType');
  }
}

/// Bit-flags defining the behavior of entities.
/// Note: Numbers indicate the bit position
abstract class OBXEntityFlags {
  /// Enable "data synchronization" for this entity type: objects will be synced with other stores over the network.
  /// It's possible to have local-only (non-synced) types and synced types in the same store (schema/data model).
  static const int SYNC_ENABLED = 2;

  /// Makes object IDs for a synced types (SYNC_ENABLED is set) global.
  /// By default (not using this flag), the 64 bit object IDs have a local scope and are not unique globally.
  /// This flag tells ObjectBox to treat object IDs globally and thus no ID mapping (local <-> global) is performed.
  /// Often this is used with assignable IDs (ID_SELF_ASSIGNABLE property flag is set) and some special ID scheme.
  /// Note: typically you won't do this with automatically assigned IDs, set by the local ObjectBox store.
  /// Two devices would likely overwrite each other's object during sync as object IDs are prone to collide.
  /// It might be OK if you can somehow ensure that only a single device will create new IDs.
  static const int SHARED_GLOBAL_IDS = 4;
}

/// Bit-flags defining the behavior of properties.
/// Note: Numbers indicate the bit position
abstract class OBXPropertyFlags {
  /// 64 bit long property (internally unsigned) representing the ID of the entity.
  /// May be combined with: NON_PRIMITIVE_TYPE, ID_MONOTONIC_SEQUENCE, ID_SELF_ASSIGNABLE.
  static const int ID = 1;

  /// On languages like Java, a non-primitive type is used (aka wrapper types, allowing null)
  static const int NON_PRIMITIVE_TYPE = 2;

  /// Unused yet
  static const int NOT_NULL = 4;
  static const int INDEXED = 8;

  /// Unused yet
  static const int RESERVED = 16;

  /// Unique index
  static const int UNIQUE = 32;

  /// Unused yet: Use a persisted sequence to enforce ID to rise monotonic (no ID reuse)
  static const int ID_MONOTONIC_SEQUENCE = 64;

  /// Allow IDs to be assigned by the developer
  static const int ID_SELF_ASSIGNABLE = 128;

  /// Unused yet
  static const int INDEX_PARTIAL_SKIP_NULL = 256;

  /// Used by References for 1) back-references and 2) to clear references to deleted objects (required for ID reuse)
  static const int INDEX_PARTIAL_SKIP_ZERO = 512;

  /// Virtual properties may not have a dedicated field in their entity class, e.g. target IDs of to-one relations
  static const int VIRTUAL = 1024;

  /// Index uses a 32 bit hash instead of the value
  /// 32 bits is shorter on disk, runs well on 32 bit systems, and should be OK even with a few collisions
  static const int INDEX_HASH = 2048;

  /// Index uses a 64 bit hash instead of the value
  /// recommended mostly for 64 bit machines with values longer >200 bytes; small values are faster with a 32 bit hash
  static const int INDEX_HASH64 = 4096;

  /// The actual type of the variable is unsigned (used in combination with numeric OBXPropertyType_*).
  /// While our default are signed ints, queries & indexes need do know signing info.
  /// Note: Don't combine with ID (IDs are always unsigned internally).
  static const int UNSIGNED = 8192;

  /// By defining an ID companion property, a special ID encoding scheme is activated involving this property.
  ///
  /// For Time Series IDs, a companion property of type Date or DateNano represents the exact timestamp.
  static const int ID_COMPANION = 16384;

  /// Unique on-conflict strategy: the object being put replaces any existing conflicting object (deletes it).
  static const int UNIQUE_ON_CONFLICT_REPLACE = 32768;
}

abstract class OBXPropertyType {
  /// < 1 byte
  static const int Bool = 1;

  /// < 1 byte
  static const int Byte = 2;

  /// < 2 bytes
  static const int Short = 3;

  /// < 1 byte
  static const int Char = 4;

  /// < 4 bytes
  static const int Int = 5;

  /// < 8 bytes
  static const int Long = 6;

  /// < 4 bytes
  static const int Float = 7;

  /// < 8 bytes
  static const int Double = 8;
  static const int String = 9;

  /// < Unix timestamp (milliseconds since 1970) in 8 bytes
  static const int Date = 10;
  static const int Relation = 11;

  /// < Unix timestamp (nanoseconds since 1970) in 8 bytes
  static const int DateNano = 12;

  /// < Flexible" type, which may contain scalars (integers, floating points), strings or
  /// < containers (lists and maps). Note: a flex map must use string keys.
  static const int Flex = 13;
  static const int ByteVector = 23;
  static const int ShortVector = 24;
  static const int CharVector = 25;
  static const int IntVector = 26;
  static const int LongVector = 27;
  static const int FloatVector = 28;
  static const int DoubleVector = 29;
  static const int StringVector = 30;
}
