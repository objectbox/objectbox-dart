/// Web (dart2js/dart2wasm) stub for `native/query/query.dart` and its parts
/// (`builder.dart`, `params.dart`, `property.dart`): mirrors the public API so
/// code compiles for web, but every operation throws [UnsupportedError] until
/// ObjectBox for web is available. See tracking issue #185.
///
/// The query property classes ([QueryProperty] and subclasses,
/// [QueryRelationToOne], [QueryRelationToMany], [QueryBacklinkToMany]) have
/// working (non-throwing) constructors on purpose: generated code creates them
/// as static final fields, so they are constructed as soon as a generated
/// `objectbox.g.dart` library is initialized. Only using them (building
/// conditions, queries) throws.
// ignore_for_file: public_member_api_docs, unused_element
library objectbox_web_query;

import 'dart:typed_data';

import '../modelinfo/index.dart';
import '../store.dart';
import '../vector_search_results.dart';
import 'unsupported.dart';

/// Groups query order flags.
class Order {
  static final descending = 1;

  static final caseSensitive = 2;

  static final unsigned = 4;

  static final nullsLast = 8;

  static final nullsAsZero = 16;
}

class QueryProperty<EntityT, DartType> {
  QueryProperty(ModelProperty model);

  Condition<EntityT> isNull({String? alias}) => throwUnsupportedOnWeb();

  Condition<EntityT> notNull({String? alias}) => throwUnsupportedOnWeb();
}

class QueryStringProperty<EntityT> extends QueryProperty<EntityT, String> {
  QueryStringProperty(super.model);

  Condition<EntityT> equals(String p, {bool? caseSensitive, String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> notEquals(
    String p, {
    bool? caseSensitive,
    String? alias,
  }) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> endsWith(String p, {bool? caseSensitive, String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> startsWith(
    String p, {
    bool? caseSensitive,
    String? alias,
  }) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> contains(String p, {bool? caseSensitive, String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> oneOf(
    List<String> list, {
    bool? caseSensitive,
    String? alias,
  }) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> greaterThan(
    String p, {
    bool? caseSensitive,
    String? alias,
  }) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> greaterOrEqual(
    String p, {
    bool? caseSensitive,
    String? alias,
  }) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> lessThan(String p, {bool? caseSensitive, String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> lessOrEqual(
    String p, {
    bool? caseSensitive,
    String? alias,
  }) =>
      throwUnsupportedOnWeb();
}

class QueryByteVectorProperty<EntityT>
    extends QueryProperty<EntityT, Uint8List> {
  QueryByteVectorProperty(super.model);

  Condition<EntityT> equals(List<int> val, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> greaterThan(List<int> val, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> greaterOrEqual(List<int> val, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> lessThan(List<int> val, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> lessOrEqual(List<int> val, {String? alias}) =>
      throwUnsupportedOnWeb();
}

class QueryIntegerProperty<EntityT> extends QueryProperty<EntityT, int> {
  QueryIntegerProperty(super.model);

  Condition<EntityT> equals(int p, {String? alias}) => throwUnsupportedOnWeb();

  Condition<EntityT> notEquals(int p, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> greaterThan(int p, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> greaterOrEqual(int p, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> lessThan(int p, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> lessOrEqual(int p, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> operator <(int p) => lessThan(p);

  Condition<EntityT> operator >(int p) => greaterThan(p);

  /// Finds objects with property value between and including the first and second value.
  Condition<EntityT> between(int p1, int p2, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> oneOf(List<int> list, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> notOneOf(List<int> list, {String? alias}) =>
      throwUnsupportedOnWeb();
}

class QueryDateProperty<EntityT> extends QueryIntegerProperty<EntityT> {
  QueryDateProperty(super.model);

  Condition<EntityT> equalsDate(DateTime value, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> notEqualsDate(DateTime value, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> greaterThanDate(DateTime value, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> greaterOrEqualDate(DateTime value, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> lessThanDate(DateTime value, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> lessOrEqualDate(DateTime value, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> betweenDate(
    DateTime value1,
    DateTime value2, {
    String? alias,
  }) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> oneOfDate(List<DateTime> values, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> notOneOfDate(List<DateTime> values, {String? alias}) =>
      throwUnsupportedOnWeb();
}

class QueryDateNanoProperty<EntityT> extends QueryIntegerProperty<EntityT> {
  QueryDateNanoProperty(super.model);

  Condition<EntityT> equalsDate(DateTime value, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> notEqualsDate(DateTime value, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> greaterThanDate(DateTime value, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> greaterOrEqualDate(DateTime value, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> lessThanDate(DateTime value, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> lessOrEqualDate(DateTime value, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> betweenDate(
    DateTime value1,
    DateTime value2, {
    String? alias,
  }) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> oneOfDate(List<DateTime> values, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> notOneOfDate(List<DateTime> values, {String? alias}) =>
      throwUnsupportedOnWeb();
}

class QueryIntegerVectorProperty<EntityT> extends QueryProperty<EntityT, int> {
  QueryIntegerVectorProperty(super.model);

  Condition<EntityT> equals(int p, {String? alias}) => throwUnsupportedOnWeb();

  Condition<EntityT> greaterThan(int p, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> greaterOrEqual(int p, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> lessThan(int p, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> lessOrEqual(int p, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> operator <(int p) => lessThan(p);

  Condition<EntityT> operator >(int p) => greaterThan(p);
}

class QueryDoubleProperty<EntityT> extends QueryProperty<EntityT, double> {
  QueryDoubleProperty(super.model);

  /// Finds objects with property value between and including the first and second value.
  Condition<EntityT> between(double p1, double p2, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> greaterThan(double p, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> greaterOrEqual(double p, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> lessThan(double p, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> lessOrEqual(double p, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> operator <(double p) => lessThan(p);

  Condition<EntityT> operator >(double p) => greaterThan(p);
}

class QueryDoubleVectorProperty<EntityT>
    extends QueryProperty<EntityT, double> {
  QueryDoubleVectorProperty(super.model);

  Condition<EntityT> greaterThan(double p, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> greaterOrEqual(double p, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> lessThan(double p, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> lessOrEqual(double p, {String? alias}) =>
      throwUnsupportedOnWeb();

  Condition<EntityT> operator <(double p) => lessThan(p);

  Condition<EntityT> operator >(double p) => greaterThan(p);
}

class QueryHnswProperty<EntityT> extends QueryDoubleVectorProperty<EntityT> {
  QueryHnswProperty(super.model);

  Condition<EntityT> nearestNeighborsF32(
    List<double> queryVector,
    int maxResultCount, {
    String? alias,
  }) =>
      throwUnsupportedOnWeb();
}

class QueryBooleanProperty<EntityT> extends QueryProperty<EntityT, bool> {
  QueryBooleanProperty(super.model);

  // ignore: avoid_positional_boolean_parameters
  Condition<EntityT> equals(bool p, {String? alias}) => throwUnsupportedOnWeb();

  // ignore: avoid_positional_boolean_parameters
  Condition<EntityT> notEquals(bool p, {String? alias}) =>
      throwUnsupportedOnWeb();
}

class QueryStringVectorProperty<EntityT>
    extends QueryProperty<EntityT, List<String>> {
  QueryStringVectorProperty(super.model);

  Condition<EntityT> containsElement(
    String value, {
    bool? caseSensitive,
    String? alias,
  }) =>
      throwUnsupportedOnWeb();
}

class QueryRelationToOne<Source, Target> extends QueryIntegerProperty<Source> {
  QueryRelationToOne(super.model);
}

class QueryRelationToMany<Source, Target> {
  QueryRelationToMany(ModelRelation model);
}

class QueryBacklinkToMany<Source, Target> {
  QueryBacklinkToMany(QueryRelationToOne<Source, Target> relProp);

  Condition<Target> relationCount(int relationCount, {String? alias}) =>
      throwUnsupportedOnWeb();
}

/// A [Query] condition base class.
abstract class Condition<EntityT> {
  // using & because && is not overridable
  Condition<EntityT> operator &(Condition<EntityT> rh) => and(rh);

  Condition<EntityT> and(Condition<EntityT> rh) => throwUnsupportedOnWeb();

  Condition<EntityT> andAll(List<Condition<EntityT>> rh) =>
      throwUnsupportedOnWeb();

  // using | because || is not overridable
  Condition<EntityT> operator |(Condition<EntityT> rh) => or(rh);

  Condition<EntityT> or(Condition<EntityT> rh) => throwUnsupportedOnWeb();

  Condition<EntityT> orAny(List<Condition<EntityT>> rh) =>
      throwUnsupportedOnWeb();
}

/// A repeatable Query returning the latest matching Objects.
class Query<T> {
  Query._();

  int get entityId => throwUnsupportedOnWeb();

  set offset(int offset) => throwUnsupportedOnWeb();

  set limit(int limit) => throwUnsupportedOnWeb();

  int count() => throwUnsupportedOnWeb();

  int remove() => throwUnsupportedOnWeb();

  Future<int> removeAsync() => throwUnsupportedOnWeb();

  void close() => throwUnsupportedOnWeb();

  T? findFirst() => throwUnsupportedOnWeb();

  Future<T?> findFirstAsync() => throwUnsupportedOnWeb();

  T? findUnique() => throwUnsupportedOnWeb();

  Future<T?> findUniqueAsync() => throwUnsupportedOnWeb();

  List<int> findIds() => throwUnsupportedOnWeb();

  Future<List<int>> findIdsAsync() => throwUnsupportedOnWeb();

  List<T> find() => throwUnsupportedOnWeb();

  Future<List<T>> findAsync() => throwUnsupportedOnWeb();

  List<IdWithScore> findIdsWithScores() => throwUnsupportedOnWeb();

  Future<List<IdWithScore>> findIdsWithScoresAsync() => throwUnsupportedOnWeb();

  List<ObjectWithScore<T>> findWithScores() => throwUnsupportedOnWeb();

  Future<List<ObjectWithScore<T>>> findWithScoresAsync() =>
      throwUnsupportedOnWeb();

  Stream<T> stream() => throwUnsupportedOnWeb();

  /// For internal testing purposes.
  String describe() => throwUnsupportedOnWeb();

  /// For internal testing purposes.
  String describeParameters() => throwUnsupportedOnWeb();

  PropertyQuery<DartType> property<DartType>(QueryProperty<T, DartType> prop) =>
      throwUnsupportedOnWeb();
}

/// Query builder allows creating reusable queries.
class QueryBuilder<T> {
  factory QueryBuilder(
    Store store,
    EntityDefinition<T> entity,
    Condition<T>? qc,
  ) =>
      throwUnsupportedOnWeb();

  Query<T> build() => throwUnsupportedOnWeb();

  Stream<Query<T>> watch({bool triggerImmediately = false}) =>
      throwUnsupportedOnWeb();

  QueryBuilder<T> order<D>(QueryProperty<T, D> p, {int flags = 0}) =>
      throwUnsupportedOnWeb();

  // Note: in the native implementation the following link methods live on a
  // private base class `_QueryBuilder` which is also their return type. As a
  // private type cannot be mirrored here, the methods are flattened into this
  // class and return [QueryBuilder], which supports the same chained calls
  // (no instance can ever exist on web anyway).

  QueryBuilder<TargetEntityT> link<TargetEntityT>(
    QueryRelationToOne<T, TargetEntityT> rel, [
    Condition<TargetEntityT>? qc,
  ]) =>
      throwUnsupportedOnWeb();

  QueryBuilder<SourceEntityT> backlink<SourceEntityT>(
    QueryRelationToOne<SourceEntityT, T> rel, [
    Condition<SourceEntityT>? qc,
  ]) =>
      throwUnsupportedOnWeb();

  QueryBuilder<TargetEntityT> linkMany<TargetEntityT>(
    QueryRelationToMany<T, TargetEntityT> rel, [
    Condition<TargetEntityT>? qc,
  ]) =>
      throwUnsupportedOnWeb();

  QueryBuilder<SourceEntityT> backlinkMany<SourceEntityT>(
    QueryRelationToMany<SourceEntityT, T> rel, [
    Condition<SourceEntityT>? qc,
  ]) =>
      throwUnsupportedOnWeb();
}

/// Adds capabilities to set query parameters
extension QuerySetParam on Query {
  QueryParam<DartType> param<EntityT, DartType>(
    QueryProperty<EntityT, DartType> prop, {
    String? alias,
  }) =>
      throwUnsupportedOnWeb();
}

/// QueryParam
class QueryParam<DartType> {
  QueryParam._();
}

/// QueryParam for string properties
extension QueryParamString on QueryParam<String> {
  set value(String value) => throwUnsupportedOnWeb();

  set values(List<String> values) => throwUnsupportedOnWeb();
}

/// QueryParam for byte vector properties
extension QueryParamBytes on QueryParam<List<int>> {
  set value(List<int> value) => throwUnsupportedOnWeb();
}

/// QueryParam for int properties
extension QueryParamInt on QueryParam<int> {
  set value(int value) => throwUnsupportedOnWeb();

  set values(List<int> values) => throwUnsupportedOnWeb();

  /// set values for condition consisting of two values
  void twoValues(int a, int b) => throwUnsupportedOnWeb();
}

/// QueryParam for double properties
extension QueryParamDouble on QueryParam<double> {
  set value(double value) => throwUnsupportedOnWeb();

  /// set values for condition consisting of two values
  void twoValues(double a, double b) => throwUnsupportedOnWeb();

  /// Set values for the nearest neighbor condition.
  void nearestNeighborsF32(List<double> queryVector, int maxResultCount) =>
      throwUnsupportedOnWeb();
}

/// QueryParam for boolean properties
extension QueryParamBool on QueryParam<bool> {
  set value(bool value) => throwUnsupportedOnWeb();
}

/// Property query base.
class PropertyQuery<T> {
  PropertyQuery._();

  /// Close the property query, freeing its resources
  void close() => throwUnsupportedOnWeb();
}

/// "Property query" for an integer field. Created by [Query.property()].
extension IntegerPropertyQuery on PropertyQuery<int> {
  double average() => throwUnsupportedOnWeb();

  int count() => throwUnsupportedOnWeb();

  bool get distinct => throwUnsupportedOnWeb();

  set distinct(bool d) => throwUnsupportedOnWeb();

  int min() => throwUnsupportedOnWeb();

  int max() => throwUnsupportedOnWeb();

  int sum() => throwUnsupportedOnWeb();

  List<int> find({int? replaceNullWith}) => throwUnsupportedOnWeb();
}

/// "Property query" for a double field. Created by [Query.property()].
extension DoublePropertyQuery on PropertyQuery<double> {
  double average() => throwUnsupportedOnWeb();

  int count() => throwUnsupportedOnWeb();

  bool get distinct => throwUnsupportedOnWeb();

  set distinct(bool d) => throwUnsupportedOnWeb();

  double min() => throwUnsupportedOnWeb();

  double max() => throwUnsupportedOnWeb();

  double sum() => throwUnsupportedOnWeb();

  List<double> find({double? replaceNullWith}) => throwUnsupportedOnWeb();
}

/// "Property query" for a string field. Created by [Query.property()].
extension StringPropertyQuery on PropertyQuery<String> {
  /// Use case-sensitive comparison when querying [distinct] values.
  set caseSensitive(bool caseSensitive) => throwUnsupportedOnWeb();

  /// Get status of the case-sensitive configuration.
  bool get caseSensitive => throwUnsupportedOnWeb();

  bool get distinct => throwUnsupportedOnWeb();

  set distinct(bool d) => throwUnsupportedOnWeb();

  int count() => throwUnsupportedOnWeb();

  List<String> find({String? replaceNullWith}) => throwUnsupportedOnWeb();
}
