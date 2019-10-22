class OBXPropertyType {
  static const int Bool = 1;
  static const int Byte = 2;
  static const int Short = 3;
  static const int Char = 4;
  static const int Int = 5;
  static const int Long = 6;
  static const int Float = 7;
  static const int Double = 8;
  static const int String = 9;
  static const int Date = 10;
  static const int Relation = 11;
  static const int ByteVector = 23;
  static const int StringVector = 30;
}

// see objectbox.h for more info
class OBXPropertyFlag {
  static const int ID = 1;
  static const int NON_PRIMITIVE_TYPE = 2;
  static const int NOT_NULL = 4;
  static const int INDEXED = 8;
  static const int RESERVED = 16;
  static const int UNIQUE = 32;
  static const int ID_MONOTONIC_SEQUENCE = 64;
  static const int ID_SELF_ASSIGNABLE = 128;
  static const int INDEX_PARTIAL_SKIP_NULL = 256;
  static const int INDEX_PARTIAL_SKIP_ZERO = 512;
  static const int VIRTUAL = 1024;
  static const int INDEX_HASH = 2048;
  static const int INDEX_HASH64 = 4096;
  static const int UNSIGNED = 8192;
}

// see objectbox.h for more info
class OBXPutMode {
  static const int PUT = 1;
  static const int INSERT = 2;
  static const int UPDATE = 3;
}

class OBXError {
  /// Successful result
  static const int OBX_SUCCESS = 0;

  /// Returned by e.g. get operations if nothing was found for a specific ID.
  /// This is NOT an error condition, and thus no last error info is set.
  static const int OBX_NOT_FOUND = 404;

  // General errors
  static const int OBX_ERROR_ILLEGAL_STATE = 10001;
  static const int OBX_ERROR_ILLEGAL_ARGUMENT = 10002;
  static const int OBX_ERROR_ALLOCATION = 10003;
  static const int OBX_ERROR_NO_ERROR_INFO = 10097;
  static const int OBX_ERROR_GENERAL = 10098;
  static const int OBX_ERROR_UNKNOWN = 10099;

  // Storage errors (often have a secondary error code)
  static const int OBX_ERROR_DB_FULL = 10101;
  static const int OBX_ERROR_MAX_READERS_EXCEEDED = 10102;
  static const int OBX_ERROR_STORE_MUST_SHUTDOWN = 10103;
  static const int OBX_ERROR_STORAGE_GENERAL = 10199;

  // Data errors
  static const int OBX_ERROR_UNIQUE_VIOLATED = 10201;
  static const int OBX_ERROR_NON_UNIQUE_RESULT = 10202;
  static const int OBX_ERROR_PROPERTY_TYPE_MISMATCH = 10203;
  static const int OBX_ERROR_CONSTRAINT_VIOLATED = 10299;

  // STD errors
  static const int OBX_ERROR_STD_ILLEGAL_ARGUMENT = 10301;
  static const int OBX_ERROR_STD_OUT_OF_RANGE = 10302;
  static const int OBX_ERROR_STD_LENGTH = 10303;
  static const int OBX_ERROR_STD_BAD_ALLOC = 10304;
  static const int OBX_ERROR_STD_RANGE = 10305;
  static const int OBX_ERROR_STD_OVERFLOW = 10306;
  static const int OBX_ERROR_STD_OTHER = 10399;

  // Inconsistencies detected
  static const int OBX_ERROR_SCHEMA = 10501;
  static const int OBX_ERROR_FILE_CORRUPT = 10502;

  /// A requested schema object (e.g. entity or property) was not found in the schema
  static const int OBX_ERROR_SCHEMA_OBJECT_NOT_FOUND = 10503;
}
