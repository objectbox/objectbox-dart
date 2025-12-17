import '../objectbox.dart';

/// An annotation to mark a class as an ObjectBox Entity. See [Entity.new].
class Entity {
  /// ObjectBox keeps track of entities and properties by assigning them unique
  /// identifiers, UIDs, during the code-generation phase. All those UIDs are
  /// stored in a file objectbox-model.json in your package and are looked up by
  /// name. If the name changes a new uid is assigned, effectively creating a
  /// new Entity in the database.
  ///
  /// If you explicitly specify a [uid] on an [Entity], ObjectBox would be able
  /// to identify it even after you change the name and would update the
  /// database accordingly on the next application launch - renaming the stored
  /// Entity instead of creating a new one.
  final int? uid;

  /// Actual type this entity represents. ObjectBox will use it instead of the
  /// `@Entity()`-annotated class's name. For example:
  /// ```dart
  /// @freezed
  /// class Person with _$Person {
  ///   @Entity(realClass: Person)
  ///   factory Person(
  ///       {@Id(assignable: true) required int id,
  ///       required String name}) = _Person;
  /// }
  /// ```
  final Type? realClass;

  /// Marks a class as an ObjectBox Entity. Allows to obtain a [Box] for this
  /// Entity from [Store] to persist instances (objects) of this class.
  const Entity({this.uid, this.realClass});
}

/// An optional annotation to configure how a field of an [Entity] class is
/// stored. See [Property.new].
class Property {
  /// ObjectBox keeps track of entities and properties by assigning them unique
  /// identifiers, UIDs, during the code-generation phase. All those UIDs are
  /// stored in a file objectbox-model.json in your package and are looked up by
  /// name. If the name changes a new uid is assigned, effectively creating a
  /// new field in the database.
  ///
  /// If you explicitly specify a [uid] on a [Property], ObjectBox would be able
  /// to identify it even after you change the name and would update the
  /// database accordingly on the next application launch - renaming the stored
  /// Property instead of creating a new one.
  final int? uid;

  /// Set to store a Dart type as an alternative ObjectBox [PropertyType].
  ///
  /// For example, a Dart [int] (64-bit signed integer) value can be stored as a
  /// shorter integer value. Or a [double] (64-bit floating point) can be stored
  /// as float (32-bit).
  ///
  /// Set [signed] to `false` to change that integers are treated as unsigned
  /// when executing queries or creating indexes.
  /// ```
  /// // Store int as a byte (8-bit integer)
  /// @Property(type: PropertyType.byte)
  /// int? byteValue;
  ///
  /// // Same, but treat values as unsigned for queries and indexes
  /// @Property(type: PropertyType.byte, signed: false)
  /// int? unsignedByteValue;
  /// ```
  final PropertyType? type;

  /// For integer property only: set to `false` to treat values as unsigned when
  /// executing queries or creating indexes. Defaults to `true`.
  final bool signed;

  /// Optionally configures how a field of an [Entity] class is stored in the
  /// database.
  ///
  /// For example:
  ///
  /// ```
  /// // Store int as a byte (8-bit integer)
  /// @Property(type: PropertyType.byte)
  /// int? byteValue;
  /// ```
  ///
  /// Learn more about customizing the database type of a property in the
  /// [online documentation](https://docs.objectbox.io/advanced/custom-types).
  const Property({this.type, this.uid, this.signed = true});
}

/// Use with [Property.type].
enum PropertyType {
  // dart type=bool, size: 1-byte/8-bits
  // no need to specify explicitly, just use [bool]
  // bool,

  /// size: 1-byte/8-bits
  byte,

  /// size: 2-bytes/16-bits
  short,

  /// Use with [Property.type] to store [int] as 2 bytes (16-bit unsigned
  /// integer).
  char,

  /// size: 4-bytes/32-bits
  int,

  // dart type=int, size: 8-bytes/64-bits
  // no need to specify explicitly, just use [int]
  // long,

  /// size: 4-bytes/32-bits
  float,

  // dart type=double, size: 8-bytes/64-bits
  // no need to specify explicitly, just use [double]
  // double,

  // dart type=String
  // no need to specify explicitly, just use [String]
  // string,

  // Relation, currently not supported
  // relation,

  /// Date stored with milliseconds precision as a Unix timestamp (64-bits).
  ///
  /// DateTime values are stored in UTC and restored in local time.
  date,

  /// Date stored with nanoseconds precision as a Unix timestamp, (64-bits).
  ///
  /// DateTime values are stored in UTC and restored in local time.
  /// Note: Dart's DateTime only supports microsecond precision.
  dateNano,

  /// Date stored with milliseconds precision as a Unix timestamp (64-bits).
  ///
  /// DateTime values are stored and restored as UTC.
  dateUtc,

  /// Date stored with nanoseconds precision as a Unix timestamp, (64-bits).
  ///
  /// DateTime values are stored and restored as UTC.
  /// This is the recommended type for "high precision" DateTime properties.
  /// Note: Dart's DateTime only supports microsecond precision.
  dateNanoUtc,

  /// Use with [Property.type] to store a `List<int>` as byte (8-bit integer)
  /// array.
  ///
  /// Integers stored in the list are truncated to their lowest 8 bits,
  /// interpreted as signed 8-bit integer with values in the range of
  /// -128 to +127.
  ///
  /// For more efficiency use `Int8List` or `Uint8List` instead.
  byteVector,

  /// Use with [Property.type] to store a `List<int>` as char (16-bit unsigned
  /// integer) array.
  charVector,

  /// Use with [Property.type] to store a `List<int>` as short (16-bit integer)
  /// array.
  ///
  /// Integers stored in the list are truncated to their lowest 16 bits,
  /// interpreted as signed 16-bit integer with values in the range of
  /// -32768 to +32767.
  ///
  /// For more efficiency use `Int16List` or `Uint16List` instead.
  shortVector,

  /// Use with [Property.type] to store a `List<int>` as int (32-bit integer)
  /// array.
  ///
  /// Integers stored in the list are truncated to their lowest 32 bits,
  /// interpreted as signed 32-bit integer with values in the range of
  /// -2147483648 to 2147483647.
  ///
  /// For more efficiency use `Int32List` or `Uint32List` instead.
  intVector,

  /// Use with [Property.type] to store a `List<double>` as float (32-bit
  /// floating point) array.
  ///
  /// Double values stored in the list are converted to the nearest
  /// single-precision value. Values read are converted to a double value with
  /// the same value.
  ///
  /// For more efficiency use `Float32List` instead.
  floatVector,

  // dart type=List<String>
  // no need to specify explicitly, just use [List<String>]
  // stringVector

  /// Use with [Property.type] to store flexible data as a FlexBuffer.
  ///
  /// Supported Dart types (auto-detected):
  /// - `Map<String, dynamic>`, `Map<String, Object?>`, or `Map<String, Object>` for maps
  /// - `List<dynamic>`, `List<Object?>`, `List<Object>`, or `List<Map<String, ...>>` for lists
  ///
  /// Supported Dart types (requires explicit annotation):
  /// - `dynamic` or `Object?` for arbitrary values (numbers, strings, lists, maps)
  ///
  /// Flex properties can store values of type: integers, floating point values,
  /// strings, booleans, null, or nested lists and maps of those types.
  flex
}

/// An annotation to mark a field of an [Entity] class as the ID property.
/// See [Id.new].
class Id {
  /// When you put a new object you don't assign an ID by default, it's assigned
  /// automatically by ObjectBox. If you need to assign IDs by yourself, use the
  /// @Id(assignable: true) annotation. This will allow putting an object with
  /// any valid ID. You can still set the ID to zero an leave it to ObjectBox.
  /// Note: in case you use [assignable] IDs on relation targets (with [ToOne]
  /// or [ToMany]), you're responsible for inserting new target objects before
  /// the source. If new objects have non-zero IDs ObjectBox has no way of
  /// telling which objects are new and which are already saved.
  final bool assignable;

  /// Marks the field of an [Entity] class as its ID property. The field must be
  /// of type [int], be non-final and have not-private visibility (or a
  /// not-private getter and setter method).
  ///
  /// ID properties are unique and indexed by default.
  const Id({this.assignable = false});
}

/// An annotation to mark a field of an [Entity] class that should not be
/// stored. See [Transient.new].
class Transient {
  /// Marks a field of an [Entity] class so it is not stored in the database.
  const Transient();
}

// See Sync() in sync.dart.
// Defining a class with the same name here would cause a duplicate export.
// class Sync {
//   const Sync();
// }

/// An annotation to create an index for a field of an [Entity] class. See
/// [Index.new].
class Index {
  /// Index type.
  final IndexType? type;

  /// Creates an index for a field of an [Entity] class.
  ///
  /// It is highly recommended to index properties that are used in a Query to
  /// improve query performance. To fine tune indexing of a property you can
  /// override the default index type.
  ///
  /// Note: indexes are currently not supported for [PropertyType.byteVector],
  /// [PropertyType.float] or [double] properties.
  const Index({this.type});
}

/// IndexType can be used to change what type ObjectBox uses when indexing a
/// property.
///
/// Limits of [hash]/[hash64] indexes: Hashes work great for equality checks,
/// but not for "starts with" conditions. If you frequently use those, consider
/// [value] indexes instead for [String] properties.
enum IndexType {
  /// Uses property values to build the index. This is a default for scalar
  /// properties.
  ///
  /// If used for a [String] property, this may require more storage space than
  /// it's default, [hash].
  value,

  /// Uses a 32-bit hash of the field value; default for [String] properties.
  ///
  /// Hash collisions should be sporadic and shouldn't impact performance in
  /// practice. Because it requires less storage space, it's usually a better
  /// choice than  [hash64].
  hash,

  /// Uses a long hash of the field value to build the index. Uses more storage
  /// space than [hash], thus should be used with consideration.
  hash64,
}

/// An annotation to create a unique index for a field of an [Entity] class. See
/// [Unique.new].
class Unique {
  /// The strategy to use when a conflict is detected when an object is put.
  final ConflictStrategy onConflict;

  /// Creates a unique index for a field of an [Entity] class.
  ///
  /// Enforces that the value of a property is unique among all objects in a Box
  /// before an object can be put.
  ///
  /// Trying to put an object with offending values will result in a
  /// [UniqueViolationException] (see [ConflictStrategy.fail]).
  /// Set [onConflict] to change this strategy.
  ///
  /// Note: Unique properties are based on an [Index], so the same restrictions
  /// apply. It is supported to explicitly add the [Index] annotation to
  /// configure the index.
  const Unique({this.onConflict = ConflictStrategy.fail});
}

/// Used with [Unique] to specify the conflict resolution strategy.
enum ConflictStrategy {
  /// Throws [UniqueViolationException] if any property violates a [Unique]
  /// constraint.
  fail,

  /// Any conflicting objects are deleted before the object is inserted.
  replace,
}

/// An annotation for a [ToMany] field of an [Entity] class to create a relation
/// based on another relation. See [Backlink.new].
class Backlink {
  /// Name of the relation the backlink should be based on (e.g. name of a
  /// [ToOne] or [ToMany] property in the target entity). Can be left empty if
  /// there is just a single relation from the target to the source entity.
  final String to;

  /// Marks a [ToMany] field in an [Entity] class to indicate the relation
  /// should be created based on another relation by reversing the direction.
  ///
  /// Pass the name of the relation the backlink should be based on (e.g. name
  /// of a [ToOne] or [ToMany] property in the target entity). Can be left empty
  /// if there is just a single relation from the target to the source entity.
  ///
  /// This works as an "updatable view" of the original relation, and doesn't
  /// cause any more data to be stored in the database. Changes made to the
  /// backlink relation are reflected in the original direction.
  ///
  /// Example ([ToOne] relation): one "Order" references one "Customer".
  /// The backlink to this is a to-many in the reverse direction: one "Customer"
  /// has a number of "Order"s.
  ///
  /// ```dart
  /// class Order {
  ///   final customer = ToOne<Customer>();
  /// }
  /// class Customer {
  ///   @Backlink()
  ///   final orders = ToMany<Customer>();
  /// }
  /// ```
  ///
  /// Example ([ToMany] relation): one "Student" references multiple "Teacher"s.
  /// The backlink to this: one "Teacher" has a number of "Student"s.
  ///
  /// ```dart
  /// class Student {
  ///   final teachers = ToMany<Teacher>();
  /// }
  /// class Teacher {
  ///   @Backlink()
  ///   final students = ToMany<Student>();
  /// }
  /// ```
  const Backlink([this.to = '']);
}

/// The vector distance algorithm used by an [HnswIndex] (vector search).
enum VectorDistanceType {
  /// The default; typically "Euclidean squared" internally.
  euclidean,

  /// Cosine similarity compares two vectors irrespective of their magnitude
  /// (compares the angle of two vectors).
  ///
  /// Often used for document or semantic similarity.
  ///
  /// Value range: 0.0 - 2.0 (0.0: same direction, 1.0: orthogonal,
  /// 2.0: opposite direction)
  cosine,

  /// For normalized vectors (vector length == 1.0), the dot product is
  /// equivalent to the cosine similarity.
  ///
  /// Because of this, the dot product is often preferred as it performs better.
  ///
  /// Value range (normalized vectors): 0.0 - 2.0 (0.0: same direction,
  /// 1.0: orthogonal, 2.0: opposite direction)
  dotProduct,

  /// A custom dot product similarity measure that does not require the vectors
  /// to be normalized.
  ///
  /// Note: this is no replacement for cosine similarity (like DotProduct for
  /// normalized vectors is). The non-linear conversion provides a high
  /// precision over the entire float range (for the raw dot product).
  /// The higher the dot product, the lower the distance is (the nearer the
  /// vectors are). The more negative the dot product, the higher the distance
  /// is (the farther the vectors are).
  ///
  /// Value range: 0.0 - 2.0 (nonlinear; 0.0: nearest, 1.0: orthogonal,
  /// 2.0: farthest)
  dotProductNonNormalized,

  /// For geospatial coordinates aka latitude/longitude pairs.
  ///
  /// Note, that the vector dimension must be 2, with the latitude being the
  /// first element and longitude the second. If the vector has more than 2
  /// dimensions, the first 2 dimensions are used. If the vector has fewer than
  /// 2 dimensions, the distance is zero.
  ///
  /// Internally, this uses haversine distance.
  ///
  /// Value range: 0 km - 6371 * π km (approx. 20015.09 km; half the Earth's
  /// circumference)
  geo
}

/// Flags as a part of the [HnswIndex] configuration.
class HnswFlags {
  /// Enables debug logs.
  final bool debugLogs;

  /// Enables "high volume" debug logs, e.g. individual gets/puts.
  final bool debugLogsDetailed;

  /// Padding for SIMD is enabled by default, which uses more memory but may be
  /// faster. This flag turns it off.
  final bool vectorCacheSimdPaddingOff;

  /// If the speed of removing nodes becomes a concern in your use case, you can
  /// speed it up by setting this flag.
  ///
  /// By default, repairing the graph after node removals creates more
  /// connections to improve the graph's quality. The extra costs for this are
  /// relatively low (e.g. vs. regular indexing), and thus the default is
  /// recommended.
  final bool reparationLimitCandidates;

  /// Create flags for the [HnswIndex] annotation.
  const HnswFlags(
      {this.debugLogs = false,
      this.debugLogsDetailed = false,
      this.vectorCacheSimdPaddingOff = false,
      this.reparationLimitCandidates = false});
}

/// An annotation to create an HSNW index for a field of an [Entity] class. See
/// [HnswIndex.new].
class HnswIndex {
  /// Dimensions of vectors; vector data with fewer dimensions are ignored.
  /// Vectors with more dimensions than specified here are only evaluated up to
  /// the given dimension value.
  ///
  /// Changing this value causes re-indexing.
  final int dimensions;

  /// Aka "M": the max number of connections per node (default: 30).
  ///
  /// Higher numbers increase the graph connectivity, which can lead to more
  /// accurate search results. However, higher numbers also increase the
  /// indexing time and resource usage.
  ///
  /// Try e.g. 16 for faster but less accurate results, or 64 for more accurate
  /// results.
  ///
  /// Changing this value causes re-indexing.
  final int? neighborsPerNode;

  /// Aka "efConstruction": the number of neighbor searched for while indexing
  /// (default: 100).
  ///
  /// The higher the value, the more accurate the search, but the longer the
  /// indexing.
  ///
  /// If indexing time is not a major concern, a value of at least 200 is
  /// recommended to improve search quality.
  ///
  /// Changing this value causes re-indexing.
  final int? indexingSearchCount;

  /// See [HnswFlags.new].
  final HnswFlags? flags;

  /// The distance type used for the HNSW index; if none is given, the default
  /// [VectorDistanceType.euclidean] is used.
  ///
  /// Changing this value causes re-indexing.
  final VectorDistanceType? distanceType;

  /// When repairing the graph after a node was removed, this gives the
  /// probability of adding backlinks to the repaired neighbors.
  ///
  /// The default is 1.0 (aka "always") as this should be worth a bit of extra
  /// costs as it improves the graph's quality.
  final double? reparationBacklinkProbability;

  /// A non-binding hint at the maximum size of the vector cache in KB
  /// (default: 2097152 or 2 GB/GiB).
  ///
  /// The actual size max cache size may be altered according to device and/or
  /// runtime settings. The vector cache is used to store vectors in memory to
  /// speed up search and indexing.
  ///
  /// Note 1: cache chunks are allocated only on demand, when they are actually
  /// used. Thus, smaller datasets will use less memory.
  ///
  /// Note 2: the cache is for one specific HNSW index; e.g. each index has its
  /// own cache.
  ///
  /// Note 3: the memory consumption can temporarily exceed the cache size, e.g.
  /// for large changes, it can double due to multi-version transactions.
  final int? vectorCacheHintSizeKB;

  /// Creates an HNSW index for a field of an [Entity] class.
  ///
  /// Use the parameters to configure HNSW-based approximate nearest neighbor
  /// (ANN) search.
  ///
  /// Some of the parameters can influence index construction and searching.
  ///
  /// Changing these values causes re-indexing, which can take a while due to
  /// the complex nature of HNSW.
  const HnswIndex(
      {required this.dimensions,
      this.neighborsPerNode,
      this.indexingSearchCount,
      this.flags,
      this.distanceType,
      this.reparationBacklinkProbability,
      this.vectorCacheHintSizeKB});
}

/// A property type of an external system (e.g. another database) that has no
/// default mapping to an ObjectBox type.
///
/// Use with [ExternalType].
enum ExternalPropertyType {
  /// Representing type: ByteVector
  ///
  /// Encoding: 1:1 binary representation, little endian (16 bytes)
  int128,

  /// A UUID (Universally Unique Identifier) as defined by RFC 9562.
  ///
  /// ObjectBox uses the UUIDv7 scheme (timestamp + random) to create new UUIDs.
  /// UUIDv7 is a good choice for database keys as it's mostly sequential and
  /// encodes a timestamp. However, if keys are used externally, consider
  /// [uuidV4] for better privacy by not exposing any time information.
  ///
  /// Representing type: ByteVector
  ///
  /// Encoding: 1:1 binary representation (16 bytes)
  uuid,

  /// IEEE 754 decimal128 type, e.g. supported by MongoDB.
  ///
  /// Representing type: ByteVector
  ///
  /// Encoding: 1:1 binary representation (16 bytes)
  decimal128,

  /// UUID represented as a string of 36 characters, e.g.
  /// "019571b4-80e3-7516-a5c1-5f1053d23fff".
  ///
  /// For efficient storage, consider the [uuid] type instead, which occupies
  /// only 16 bytes (20 bytes less). This type may still be a convenient
  /// alternative as the string type is widely supported and more
  /// human-readable. In accordance to standards, new UUIDs generated by
  /// ObjectBox use lowercase hexadecimal digits.
  ///
  /// Representing type: String
  uuidString,

  /// A UUID (Universally Unique Identifier) as defined by RFC 9562.
  ///
  /// ObjectBox uses the UUIDv4 scheme (completely random) to create new UUIDs.
  ///
  /// Representing type: ByteVector
  ///
  /// Encoding: 1:1 binary representation (16 bytes)
  uuidV4,

  /// Like [uuidString], but using the UUIDv4 scheme (completely random) to
  /// create new UUID.
  ///
  /// Representing type: String
  uuidV4String,

  /// A key/value map; e.g. corresponds to a JSON object or a MongoDB document
  /// (although not keeping the key order).
  ///
  /// Unlike the Flex type, this must contain a map value (e.g. not a vector or
  /// a scalar).
  ///
  /// Representing type: Flex
  ///
  /// Encoding: Flex
  flexMap,

  /// A vector (aka list or array) of flexible elements; e.g. corresponds to a
  /// JSON array or a MongoDB array.
  ///
  /// Unlike the Flex type, this must contain a vector value (e.g. not a map or
  /// a scalar).
  ///
  /// Representing type: Flex
  ///
  /// Encoding: Flex
  flexVector,

  /// Placeholder (not yet used) for a JSON document.
  ///
  /// Representing type: String
  json,

  /// Placeholder (not yet used) for a BSON document.
  ///
  /// Representing type: ByteVector
  bson,

  /// JavaScript source code.
  ///
  /// Representing type: String
  javaScript,

  /// A JSON string that is converted to a native representation in the external
  /// system.
  ///
  /// For example, a JSON object on the ObjectBox side (string) would be
  /// converted to an embedded document in MongoDB.
  ///
  /// It depends on the external system what kind of JSON structures is
  /// supported. For MongoDB, this is very flexible and allows (nested) objects,
  /// arrays, primitives, etc.
  ///
  /// Representing type: String
  jsonToNative,

  /// A vector (array) of Int128 values.
  int128Vector,

  /// A vector (array) of Uuid values
  uuidVector,

  /// The 12-byte ObjectId type in MongoDB.
  ///
  /// Representing type: ByteVector
  ///
  /// Encoding: 1:1 binary representation (12 bytes)
  mongoId,

  /// A vector (array) of MongoId values.
  mongoIdVector,

  /// Representing type: Long
  ///
  /// Encoding: Two unsigned 32-bit integers merged into a 64-bit integer.
  mongoTimestamp,

  /// Representing type: ByteVector
  ///
  /// Encoding: 3 zero bytes (reserved, functions as padding), fourth byte is
  /// the sub-type, followed by the binary data.
  mongoBinary,

  /// Representing type: string vector with 2 elements (index 0: pattern,
  /// index 1: options)
  ///
  /// Encoding: 1:1 string representation
  mongoRegex
}

/// An annotation to specify the type of a field in an [Entity] class in an
/// external system. See [ExternalType.new].
class ExternalType {
  /// The type of the property in the external system.
  ///
  /// See [ExternalPropertyType] for possible values.
  final ExternalPropertyType type;

  /// Sets the type of a field in an [Entity] class in an external system (like
  /// another database).
  ///
  /// When used on a [ToMany] field, this sets the type of the object IDs
  /// of the relation instead.
  ///
  /// This is useful if there is no default mapping of the ObjectBox type to the
  /// type in the external system.
  ///
  /// Carefully look at the documentation of the external type to ensure it is
  /// compatible with the ObjectBox type.
  const ExternalType({required this.type});
}

/// An annotation to specify the name of an [Entity] class or field of an
/// [Entity] class in an external system. See [ExternalName.new].
class ExternalName {
  /// The name assigned to the property in the external system.
  final String name;

  /// Sets the name of an [Entity] class or a field of an [Entity] class in an
  /// external system (like another database).
  ///
  /// The field may be of type [ToMany].
  const ExternalName({required this.name});
}

/// An annotation for a [ToOne] to change the name of its target ID property.
class TargetIdProperty {
  /// Name used in the database.
  final String name;

  /// For a `ToOne`, changes the name of its associated target ID (or
  /// "relation") property.
  ///
  /// ```dart
  /// @Entity()
  /// class Order {
  ///     // Change from default "customerId" to "customerRef"
  ///     @TargetIdProperty("customerRef")
  ///     final customer = ToOne<Customer>();
  /// }
  /// ```
  ///
  /// A target ID property is implicitly created (so without defining it in
  /// the `@Entity` class) for each `ToOne` and stores the ID of the referenced
  /// target object. By default, it's named like the `ToOne` field plus the
  /// suffix `Id` (for example `customerId`).
  ///
  /// See the [relations documentation](https://docs.objectbox.io/relations) for
  /// details.
  const TargetIdProperty(this.name);
}
