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
    case OBXPropertyType.Flex:
      return 'flex';
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
    case PropertyType.dateUtc:
      return OBXPropertyType.Date;
    case PropertyType.dateNano:
    case PropertyType.dateNanoUtc:
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
    case PropertyType.flex:
      return OBXPropertyType.Flex;
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

  /// If a date property has this flag (max. one per entity type), the date value specifies the time by which
  /// the object expires, at which point it MAY be removed (deleted), which can be triggered by an API call.
  static const int EXPIRATION_TIME = 65536;
}

abstract class OBXPropertyType {
  /// < Not a actual type; represents an uninitialized or invalid type
  static const int Unknown = 0;

  /// < A boolean (flag)
  static const int Bool = 1;

  /// < 8-bit integer
  static const int Byte = 2;

  /// < 16-bit integer
  static const int Short = 3;

  /// < 16-bit character
  static const int Char = 4;

  /// < 32-bit integer
  static const int Int = 5;

  /// < 64-bit integer
  static const int Long = 6;

  /// < 32-bit floating point number
  static const int Float = 7;

  /// < 64-bit floating point number
  static const int Double = 8;

  /// < UTF-8 encoded string (variable length)
  static const int String = 9;

  /// < 64-bit (integer) timestamp; milliseconds since 1970-01-01 (unix epoch)
  static const int Date = 10;

  /// < Relation to another entity
  static const int Relation = 11;

  /// < High precision 64-bit timestamp; nanoseconds since 1970-01-01 (unix epoch)
  static const int DateNano = 12;

  /// < Flexible" type, which may contain scalars (integers, floating points), strings or
  /// < containers (lists and maps). Note: a flex map must use string keys.
  static const int Flex = 13;

  /// < Variable sized vector of Bool values (note: each value is one byte)
  static const int BoolVector = 22;

  /// < Variable sized vector of Byte values (8-bit integers)
  static const int ByteVector = 23;

  /// < Variable sized vector of Short values (16-bit integers)
  static const int ShortVector = 24;

  /// < Variable sized vector of Char values (16-bit characters)
  static const int CharVector = 25;

  /// < Variable sized vector of Int values (32-bit integers)
  static const int IntVector = 26;

  /// < Variable sized vector of Long values (64-bit integers)
  static const int LongVector = 27;

  /// < Variable sized vector of Float values (32-bit floating point numbers)
  static const int FloatVector = 28;

  /// < Variable sized vector of Double values (64-bit floating point numbers)
  static const int DoubleVector = 29;

  /// < Variable sized vector of String values (UTF-8 encoded strings).
  static const int StringVector = 30;

  /// < Variable sized vector of Date values (64-bit timestamp).
  static const int DateVector = 31;

  /// < Variable sized vector of Date values (high precision 64-bit timestamp).
  static const int DateNanoVector = 32;
}

int externalTypeToOBXExternalType(ExternalPropertyType type) {
  switch (type) {
    case ExternalPropertyType.int128:
      return OBXExternalPropertyType.Int128;
    case ExternalPropertyType.uuid:
      return OBXExternalPropertyType.Uuid;
    case ExternalPropertyType.decimal128:
      return OBXExternalPropertyType.Decimal128;
    case ExternalPropertyType.flexMap:
      return OBXExternalPropertyType.FlexMap;
    case ExternalPropertyType.flexVector:
      return OBXExternalPropertyType.FlexVector;
    case ExternalPropertyType.json:
      return OBXExternalPropertyType.Json;
    case ExternalPropertyType.bson:
      return OBXExternalPropertyType.Bson;
    case ExternalPropertyType.javaScript:
      return OBXExternalPropertyType.JavaScript;
    case ExternalPropertyType.jsonToNative:
      return OBXExternalPropertyType.JsonToNative;
    case ExternalPropertyType.int128Vector:
      return OBXExternalPropertyType.Int128Vector;
    case ExternalPropertyType.uuidVector:
      return OBXExternalPropertyType.UuidVector;
    case ExternalPropertyType.mongoId:
      return OBXExternalPropertyType.MongoId;
    case ExternalPropertyType.mongoIdVector:
      return OBXExternalPropertyType.MongoIdVector;
    case ExternalPropertyType.mongoTimestamp:
      return OBXExternalPropertyType.MongoTimestamp;
    case ExternalPropertyType.mongoBinary:
      return OBXExternalPropertyType.MongoBinary;
    case ExternalPropertyType.mongoRegex:
      return OBXExternalPropertyType.MongoRegex;
    default:
      throw ArgumentError.value(type, 'type', 'Invalid ExternalType');
  }
}

/// A property type of an external system (e.g. another database) that has no default mapping to an ObjectBox type.
/// External property types numeric values start at 100 to avoid overlaps with ObjectBox's PropertyType.
/// (And if we ever support one of these as a primary type, we could share the numeric value?)
abstract class OBXExternalPropertyType {
  /// Not a real type: represents uninitialized state and can be used for forward compatibility.
  static const int Unknown = 0;

  /// Representing type: ByteVector
  /// Encoding: 1:1 binary representation, little endian (16 bytes)
  static const int Int128 = 100;

  /// Representing type: ByteVector
  /// Encoding: 1:1 binary representation (16 bytes)
  static const int Uuid = 102;

  /// IEEE 754 decimal128 type, e.g. supported by MongoDB
  /// Representing type: ByteVector
  /// Encoding: 1:1 binary representation (16 bytes)
  static const int Decimal128 = 103;

  /// A key/value map; e.g. corresponds to a JSON object or a MongoDB document (although not keeping the key order).
  /// Unlike the Flex type, this must contain a map value (e.g. not a vector or a scalar).
  /// Representing type: Flex
  /// Encoding: Flex
  static const int FlexMap = 107;

  /// A vector (aka list or array) of flexible elements; e.g. corresponds to a JSON array or a MongoDB array.
  /// Unlike the Flex type, this must contain a vector value (e.g. not a map or a scalar).
  /// Representing type: Flex
  /// Encoding: Flex
  static const int FlexVector = 108;

  /// Placeholder (not yet used) for a JSON document.
  /// Representing type: String
  static const int Json = 109;

  /// Placeholder (not yet used) for a BSON document.
  /// Representing type: ByteVector
  static const int Bson = 110;

  /// JavaScript source code
  /// Representing type: String
  static const int JavaScript = 111;

  /// A JSON string that is converted to a native representation in the external system.
  /// For example, a JSON object on the ObjectBox side (string) would be converted to an embedded document in MongoDB.
  /// It depends on the external system what kind of JSON structures is supported.
  /// For MongoDB, this is very flexible and allows (nested) objects, arrays, primitives, etc.
  /// Representing type: String
  static const int JsonToNative = 112;

  /// A vector (array) of Int128 values
  static const int Int128Vector = 116;

  /// A vector (array) of Int128 values
  static const int UuidVector = 118;

  /// The 12-byte ObjectId type in MongoDB
  /// Representing type: ByteVector
  /// Encoding: 1:1 binary representation (12 bytes)
  static const int MongoId = 123;

  /// A vector (array) of MongoId values
  static const int MongoIdVector = 124;

  /// Representing type: Long
  /// Encoding: Two unsigned 32-bit integers merged into a 64-bit integer.
  static const int MongoTimestamp = 125;

  /// Representing type: ByteVector
  /// Encoding: 3 zero bytes (reserved, functions as padding), fourth byte is the sub-type,
  /// followed by the binary data.
  static const int MongoBinary = 126;

  /// Representing type: string vector with 2 elements (index 0: pattern, index 1: options)
  /// Encoding: 1:1 string representation
  static const int MongoRegex = 127;
}

/// Flags to adjust Sync client behavior.
abstract class OBXSyncFlags {
  /// Enable (rather extensive) logging on how IDs are mapped (local <-> global)
  static const int DebugLogIdMapping = 1;

  /// If the client gets in a state that does not allow any further synchronization, this flag instructs Sync to
  /// keep local data nevertheless. While this preserves data, you need to resolve the situation manually.
  /// For example, you could backup the data and start with a fresh database.
  /// Note that the default behavior (this flag is not set) is to wipe existing data from all sync-enabled types and
  /// sync from scratch from the server.
  /// Client-only: setting this flag for Sync server has no effect.
  static const int KeepDataOnSyncError = 2;

  /// Logs Sync filter variables used for each client, e.g. values provided by JWT or the client's login message.
  static const int DebugLogFilterVariables = 4;

  /// When set, remove operations will include the full object data in the TX log (REMOVE_OBJECT command).
  /// This allows Sync filters to filter out remove operations based on the object content.
  /// Without this flag, remove operations only contain the object ID and cannot be filtered.
  /// Note: this increases the size of TX logs for remove operations.
  static const int RemoveWithObjectData = 8;

  /// Enables debug logging of TX log processing.
  /// For now, this only has an effect on SyncClients (Sync Server has extensive debug logs already).
  static const int DebugLogTxLogs = 16;

  // Note: manually added, 5.1.0 release objectbox-sync.h file is missing it
  /// Skips invalid (put object) operations in the TX log instead of failing.
  static const int SkipInvalidTxOps = 32;
}
