import '../objectbox.dart';

/// Entity annotation is used on a class to let ObjectBox know it should store
/// it - making the class a "persistable Entity".
///
/// This annotation is matched by ObjectBox code generator when you call
/// `pub run_build_runner build`. The generator creates `objectbox.g.dart` with
/// all the binding code necessary to store the class in the database.
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

  /// Create an Entity annotation.
  const Entity({this.uid, this.realClass});
}

/// Use to (optionally) annotate a field to explicitly configure some details about
/// how a field is stored in the database.
///
/// For example:
/// ```
/// // Store int as a byte (8-bit integer)
/// @Property(type: PropertyType.byte)
/// int? byteValue;
/// ```
/// See [the online docs](https://docs.objectbox.io/advanced/custom-types) for
/// details.
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

  /// See [Property].
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

  /// Use with [Property.type] to store [int] as 2 bytes (16-bit unsigned integer).
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

  /// Unix timestamp (milliseconds since 1970), size: 8-bytes/64-bits
  date,

  /// Unix timestamp (nanoseconds since 1970), size: 8-bytes/64-bits
  dateNano,

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
  floatVector

  // dart type=List<String>
  // no need to specify explicitly, just use [List<String>]
  // stringVector
}

/// Annotation Id can be used to specify an entity ID property if it's named
/// anything else then "id" (case insensitive).
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

  /// Create an Id annotation.
  const Id({this.assignable = false});
}

/// Transient annotation marks fields that should not be stored in the database.
class Transient {
  /// Create a Transient annotation.
  const Transient();
}

// See Sync() in sync.dart.
// Defining a class with the same name here would cause a duplicate export.
// class Sync {
//   const Sync();
// }

/// Specifies that the property should be indexed.
///
/// It is highly recommended to index properties that are used in a Query to
/// improve query performance. To fine tune indexing of a property you can
/// override the default index type.
///
/// Note: indexes are currently not supported for ByteVector, Float or Double
/// properties.
class Index {
  /// Index type.
  final IndexType? type;

  /// Create an Index annotation.
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

/// Enforces that the value of a property is unique among all objects in a box
/// before an object can be put.
///
/// Trying to put an object with offending values will result in a
/// [UniqueViolationException] (see [ConflictStrategy.fail]).
/// Set [onConflict] to change this strategy.
///
/// Note: Unique properties are based on an [Index], so the same restrictions apply.
/// It is supported to explicitly add the [Index] annotation to configure the
/// index.
class Unique {
  /// The strategy to use when a conflict is detected when an object is put.
  final ConflictStrategy onConflict;

  /// Create a Unique annotation.
  const Unique({this.onConflict = ConflictStrategy.fail});
}

/// Used with [Unique] to specify the conflict resolution strategy.
enum ConflictStrategy {
  /// Throws [UniqueViolationException] if any property violates a [Unique] constraint.
  fail,

  /// Any conflicting objects are deleted before the object is inserted.
  replace,
}

/// Backlink annotation specifies a link in a reverse direction of another
/// relation.
///
/// This works as an "updatable view" of the original relation, and doesn't
/// cause any more data to be stored in the database. Changes made to the
/// backlink relation are reflected in the original direction.
///
/// Example - backlink based on a [ToOne] relation:
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
/// Example - backlink based on a [ToMany] relation:
/// ```dart
/// class Student {
///   final teachers = ToMany<Teacher>();
/// }
/// class Teacher {
///   @Backlink()
///   final students = ToMany<Student>();
/// }
/// ```
class Backlink {
  /// Target entity to which this backlink points. It's the entity that contains
  /// a [ToOne] or [ToMany] relation pointing to the current entity.
  final String to;

  /// If there are multiple relations pointing to the current entity, specify
  /// the field name of the desired source relation: Backlink('sourceField').
  const Backlink([this.to = '']);
}

/// The vector distance algorithm used by an [HnswIndex] (vector search).
enum VectorDistanceType {
  /// The default; typically "Euclidean squared" internally.
  euclidean,

  /// Cosine similarity compares two vectors irrespective of their magnitude (compares the angle of two vectors).
  ///
  /// Often used for document or semantic similarity.
  ///
  /// Value range: 0.0 - 2.0 (0.0: same direction, 1.0: orthogonal, 2.0: opposite direction)
  cosine,

  /// For normalized vectors (vector length == 1.0), the dot product is equivalent to the cosine similarity.
  ///
  /// Because of this, the dot product is often preferred as it performs better.
  ///
  /// Value range (normalized vectors): 0.0 - 2.0 (0.0: same direction, 1.0: orthogonal, 2.0: opposite direction)
  dotProduct,

  /// A custom dot product similarity measure that does not require the vectors to be normalized.
  ///
  /// Note: this is no replacement for cosine similarity (like DotProduct for normalized vectors is).
  /// The non-linear conversion provides a high precision over the entire float range (for the raw dot product).
  /// The higher the dot product, the lower the distance is (the nearer the vectors are).
  /// The more negative the dot product, the higher the distance is (the farther the vectors are).
  ///
  /// Value range: 0.0 - 2.0 (nonlinear; 0.0: nearest, 1.0: orthogonal, 2.0: farthest)
  dotProductNonNormalized
}

/// Flags as a part of the [HnswIndex] configuration.
class HnswFlags {
  /// Enables debug logs.
  final bool debugLogs;

  /// Enables "high volume" debug logs, e.g. individual gets/puts.
  final bool debugLogsDetailed;

  /// Padding for SIMD is enabled by default, which uses more memory but may be faster. This flag turns it off.
  final bool vectorCacheSimdPaddingOff;

  /// If the speed of removing nodes becomes a concern in your use case, you can speed it up by setting this flag.
  /// By default, repairing the graph after node removals creates more connections to improve the graph's quality.
  /// The extra costs for this are relatively low (e.g. vs. regular indexing), and thus the default is recommended.
  final bool reparationLimitCandidates;

  /// Create flags for the [HnswIndex] annotation.
  const HnswFlags(
      {this.debugLogs = false,
      this.debugLogsDetailed = false,
      this.vectorCacheSimdPaddingOff = false,
      this.reparationLimitCandidates = false});
}

/// See [HnswIndex.new].
class HnswIndex {
  /// Dimensions of vectors; vector data with fewer dimensions are ignored.
  /// Vectors with more dimensions than specified here are only evaluated up to the given dimension value.
  /// Changing this value causes re-indexing.
  final int dimensions;

  /// Aka "M": the max number of connections per node (default: 30).
  /// Higher numbers increase the graph connectivity, which can lead to more accurate search results.
  /// However, higher numbers also increase the indexing time and resource usage.
  /// Try e.g. 16 for faster but less accurate results, or 64 for more accurate results.
  /// Changing this value causes re-indexing.
  final int? neighborsPerNode;

  /// Aka "efConstruction": the number of neighbor searched for while indexing (default: 100).
  /// The higher the value, the more accurate the search, but the longer the indexing.
  /// If indexing time is not a major concern, a value of at least 200 is recommended to improve search quality.
  /// Changing this value causes re-indexing.
  final int? indexingSearchCount;

  /// See [HnswFlags.new].
  final HnswFlags? flags;

  /// The distance type used for the HNSW index; if none is given, the default [VectorDistanceType.euclidean] is used.
  ///
  /// Changing this value causes re-indexing.
  final VectorDistanceType? distanceType;

  /// When repairing the graph after a node was removed, this gives the probability of adding backlinks to the
  /// repaired neighbors.
  /// The default is 1.0 (aka "always") as this should be worth a bit of extra costs as it improves the graph's
  /// quality.
  final double? reparationBacklinkProbability;

  /// A non-binding hint at the maximum size of the vector cache in KB (default: 2097152 or 2 GB/GiB).
  /// The actual size max cache size may be altered according to device and/or runtime settings.
  /// The vector cache is used to store vectors in memory to speed up search and indexing.
  ///
  /// Note 1: cache chunks are allocated only on demand, when they are actually used.
  ///         Thus, smaller datasets will use less memory.
  ///
  /// Note 2: the cache is for one specific HNSW index; e.g. each index has its own cache.
  ///
  /// Note 3: the memory consumption can temporarily exceed the cache size,
  ///         e.g. for large changes, it can double due to multi-version transactions.
  final int? vectorCacheHintSizeKB;

  /// Parameters to configure HNSW-based approximate nearest neighbor (ANN) search.
  /// Some of the parameters can influence index construction and searching.
  /// Changing these values causes re-indexing, which can take a while due to the
  /// complex nature of HNSW.
  const HnswIndex(
      {required this.dimensions,
      this.neighborsPerNode,
      this.indexingSearchCount,
      this.flags,
      this.distanceType,
      this.reparationBacklinkProbability,
      this.vectorCacheHintSizeKB});
}
