library query;

import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../../annotations.dart';
import '../../common.dart';
import '../../modelinfo/entity_definition.dart';
import '../../modelinfo/modelproperty.dart';
import '../../modelinfo/modelrelation.dart';
import '../../store.dart';
import '../../transaction.dart';
import '../bindings/bindings.dart';
import '../bindings/data_visitor.dart';
import '../bindings/helpers.dart';
import '../box.dart';
import 'vector_search_results.dart';

part 'builder.dart';

part 'params.dart';

part 'property.dart';

// ignore_for_file: public_member_api_docs

/// Groups query order flags.
class Order {
  /// Reverts the order from ascending (default) to descending.
  static final descending = 1;

  /// Sorts upper case letters (e.g. 'Z') before lower case letters (e.g. 'a').
  /// If not specified, the default is case insensitive for ASCII characters.
  static final caseSensitive = 2;

  /// For integers only: changes the comparison to unsigned. The default is
  /// signed, unless the property is annotated with `@Property(signed: false)`.
  static final unsigned = 4;

  /// null values will be put last.
  /// If not specified, by default null values will be put first.
  static final nullsLast = 8;

  /// null values should be treated equal to zero (scalars only).
  static final nullsAsZero = 16;
}

/// The QueryProperty types allow users to build query conditions on a property.
class QueryProperty<EntityT, DartType> {
  final ModelProperty _model;

  QueryProperty(this._model);

  Condition<EntityT> isNull({String? alias}) =>
      _NullCondition<EntityT, DartType>(_ConditionOp.isNull, this, alias);

  Condition<EntityT> notNull({String? alias}) =>
      _NullCondition<EntityT, DartType>(_ConditionOp.notNull, this, alias);
}

class QueryStringProperty<EntityT> extends QueryProperty<EntityT, String> {
  QueryStringProperty(super.model);

  Condition<EntityT> _op(String p, _ConditionOp cop, String? alias,
          {bool? caseSensitive}) =>
      _StringCondition<EntityT, String>(cop, this, p, null, alias,
          caseSensitive: caseSensitive);

  Condition<EntityT> _opList(List<String> list, _ConditionOp cop, String? alias,
          {bool? caseSensitive}) =>
      _StringListCondition<EntityT>(cop, this, list, alias,
          caseSensitive: caseSensitive);

  Condition<EntityT> equals(String p, {bool? caseSensitive, String? alias}) =>
      _op(p, _ConditionOp.eq, alias, caseSensitive: caseSensitive);

  Condition<EntityT> notEquals(String p,
          {bool? caseSensitive, String? alias}) =>
      _op(p, _ConditionOp.notEq, alias, caseSensitive: caseSensitive);

  Condition<EntityT> endsWith(String p, {bool? caseSensitive, String? alias}) =>
      _op(p, _ConditionOp.endsWith, alias, caseSensitive: caseSensitive);

  Condition<EntityT> startsWith(String p,
          {bool? caseSensitive, String? alias}) =>
      _op(p, _ConditionOp.startsWith, alias, caseSensitive: caseSensitive);

  Condition<EntityT> contains(String p, {bool? caseSensitive, String? alias}) =>
      _op(p, _ConditionOp.contains, alias, caseSensitive: caseSensitive);

  Condition<EntityT> oneOf(List<String> list,
          {bool? caseSensitive, String? alias}) =>
      _opList(list, _ConditionOp.oneOf, alias, caseSensitive: caseSensitive);

  // currently not supported by the C-API
  // Condition<EntityT> notOneOf(List<String> list, {bool? caseSensitive,
  //     String? alias}) => _opList(list, _ConditionOp.notOneOf, alias,
  //     caseSensitive: caseSensitive);

  Condition<EntityT> greaterThan(String p,
          {bool? caseSensitive, String? alias}) =>
      _op(p, _ConditionOp.gt, alias, caseSensitive: caseSensitive);

  Condition<EntityT> greaterOrEqual(String p,
          {bool? caseSensitive, String? alias}) =>
      _op(p, _ConditionOp.greaterOrEq, alias, caseSensitive: caseSensitive);

  Condition<EntityT> lessThan(String p, {bool? caseSensitive, String? alias}) =>
      _op(p, _ConditionOp.lt, alias, caseSensitive: caseSensitive);

  Condition<EntityT> lessOrEqual(String p,
          {bool? caseSensitive, String? alias}) =>
      _op(p, _ConditionOp.lessOrEq, alias, caseSensitive: caseSensitive);
}

class QueryByteVectorProperty<EntityT>
    extends QueryProperty<EntityT, Uint8List> {
  QueryByteVectorProperty(super.model);

  Condition<EntityT> _op(List<int> val, _ConditionOp cop, String? alias) =>
      _ByteVectorCondition<EntityT>(cop, this, Uint8List.fromList(val), alias);

  Condition<EntityT> equals(List<int> val, {String? alias}) =>
      _op(val, _ConditionOp.eq, alias);

  Condition<EntityT> greaterThan(List<int> val, {String? alias}) =>
      _op(val, _ConditionOp.gt, alias);

  Condition<EntityT> greaterOrEqual(List<int> val, {String? alias}) =>
      _op(val, _ConditionOp.greaterOrEq, alias);

  Condition<EntityT> lessThan(List<int> val, {String? alias}) =>
      _op(val, _ConditionOp.lt, alias);

  Condition<EntityT> lessOrEqual(List<int> val, {String? alias}) =>
      _op(val, _ConditionOp.lessOrEq, alias);
}

class QueryIntegerProperty<EntityT> extends QueryProperty<EntityT, int> {
  QueryIntegerProperty(super.model);

  Condition<EntityT> _op(_ConditionOp cop, int p1, int p2, String? alias) =>
      _IntegerCondition<EntityT, int>(cop, this, p1, p2, alias);

  Condition<EntityT> _opList(List<int> list, _ConditionOp cop, String? alias) =>
      _IntegerListCondition<EntityT>(cop, this, list, alias);

  Condition<EntityT> equals(int p, {String? alias}) =>
      _op(_ConditionOp.eq, p, 0, alias);

  Condition<EntityT> notEquals(int p, {String? alias}) =>
      _op(_ConditionOp.notEq, p, 0, alias);

  Condition<EntityT> greaterThan(int p, {String? alias}) =>
      _op(_ConditionOp.gt, p, 0, alias);

  Condition<EntityT> greaterOrEqual(int p, {String? alias}) =>
      _op(_ConditionOp.greaterOrEq, p, 0, alias);

  Condition<EntityT> lessThan(int p, {String? alias}) =>
      _op(_ConditionOp.lt, p, 0, alias);

  Condition<EntityT> lessOrEqual(int p, {String? alias}) =>
      _op(_ConditionOp.lessOrEq, p, 0, alias);

  Condition<EntityT> operator <(int p) => lessThan(p);

  Condition<EntityT> operator >(int p) => greaterThan(p);

  /// Finds objects with property value between and including the first and second value.
  Condition<EntityT> between(int p1, int p2, {String? alias}) =>
      _op(_ConditionOp.between, p1, p2, alias);

  Condition<EntityT> oneOf(List<int> list, {String? alias}) =>
      _opList(list, _ConditionOp.oneOf, alias);

  Condition<EntityT> notOneOf(List<int> list, {String? alias}) =>
      _opList(list, _ConditionOp.notOneOf, alias);
}

/// This wraps [QueryIntegerProperty] for [DateTime] properties to avoid
/// having to manually convert to [DateTime.millisecondsSinceEpoch] when
/// creating query conditions.
class QueryDateProperty<EntityT> extends QueryIntegerProperty<EntityT> {
  QueryDateProperty(super.model);

  int _convert(DateTime value) => value.millisecondsSinceEpoch;

  /// Like [equals], but first converts to [DateTime.millisecondsSinceEpoch].
  Condition<EntityT> equalsDate(DateTime value, {String? alias}) =>
      equals(_convert(value), alias: alias);

  /// Like [notEquals], but first converts to [DateTime.millisecondsSinceEpoch].
  Condition<EntityT> notEqualsDate(DateTime value, {String? alias}) =>
      notEquals(_convert(value), alias: alias);

  /// Like [greaterThan], but first converts to [DateTime.millisecondsSinceEpoch].
  Condition<EntityT> greaterThanDate(DateTime value, {String? alias}) =>
      greaterThan(_convert(value), alias: alias);

  /// Like [greaterOrEqual], but first converts to [DateTime.millisecondsSinceEpoch].
  Condition<EntityT> greaterOrEqualDate(DateTime value, {String? alias}) =>
      greaterOrEqual(_convert(value), alias: alias);

  /// Like [lessThan], but first converts to [DateTime.millisecondsSinceEpoch].
  Condition<EntityT> lessThanDate(DateTime value, {String? alias}) =>
      lessThan(_convert(value), alias: alias);

  /// Like [lessOrEqual], but first converts to [DateTime.millisecondsSinceEpoch].
  Condition<EntityT> lessOrEqualDate(DateTime value, {String? alias}) =>
      lessOrEqual(_convert(value), alias: alias);

  /// Like [between], but first converts to [DateTime.millisecondsSinceEpoch].
  Condition<EntityT> betweenDate(DateTime value1, DateTime value2,
          {String? alias}) =>
      between(_convert(value1), _convert(value2), alias: alias);

  /// Like [oneOf], but first converts to [DateTime.millisecondsSinceEpoch].
  Condition<EntityT> oneOfDate(List<DateTime> values, {String? alias}) =>
      oneOf(values.map(_convert).toList(), alias: alias);

  /// Like [notOneOf], but first converts to [DateTime.millisecondsSinceEpoch].
  Condition<EntityT> notOneOfDate(List<DateTime> values, {String? alias}) =>
      notOneOf(values.map(_convert).toList(), alias: alias);
}

/// This wraps [QueryIntegerProperty] for [DateTime] properties annotated with
/// `@Property(type: PropertyType.dateNano)` or
/// `@Property(type: PropertyType.dateNanoUtc)` to avoid having to manually convert
/// to nanoseconds ([DateTime.microsecondsSinceEpoch] `* 1000`) when creating
/// query conditions.
class QueryDateNanoProperty<EntityT> extends QueryIntegerProperty<EntityT> {
  QueryDateNanoProperty(super.model);

  int _convert(DateTime value) => value.microsecondsSinceEpoch * 1000;

  /// Like [equals], but first converts to nanoseconds
  /// ([DateTime.microsecondsSinceEpoch] `* 1000`).
  Condition<EntityT> equalsDate(DateTime value, {String? alias}) =>
      equals(_convert(value), alias: alias);

  /// Like [notEquals], but first converts to nanoseconds
  /// ([DateTime.microsecondsSinceEpoch] `* 1000`).
  Condition<EntityT> notEqualsDate(DateTime value, {String? alias}) =>
      notEquals(_convert(value), alias: alias);

  /// Like [greaterThan], but first converts to nanoseconds
  /// ([DateTime.microsecondsSinceEpoch] `* 1000`).
  Condition<EntityT> greaterThanDate(DateTime value, {String? alias}) =>
      greaterThan(_convert(value), alias: alias);

  /// Like [greaterOrEqual], but first converts to nanoseconds
  /// ([DateTime.microsecondsSinceEpoch] `* 1000`).
  Condition<EntityT> greaterOrEqualDate(DateTime value, {String? alias}) =>
      greaterOrEqual(_convert(value), alias: alias);

  /// Like [lessThan], but first converts to nanoseconds
  /// ([DateTime.microsecondsSinceEpoch] `* 1000`).
  Condition<EntityT> lessThanDate(DateTime value, {String? alias}) =>
      lessThan(_convert(value), alias: alias);

  /// Like [lessOrEqual], but first converts to nanoseconds
  /// ([DateTime.microsecondsSinceEpoch] `* 1000`).
  Condition<EntityT> lessOrEqualDate(DateTime value, {String? alias}) =>
      lessOrEqual(_convert(value), alias: alias);

  /// Like [between], but first converts to nanoseconds
  /// ([DateTime.microsecondsSinceEpoch] `* 1000`).
  Condition<EntityT> betweenDate(DateTime value1, DateTime value2,
          {String? alias}) =>
      between(_convert(value1), _convert(value2), alias: alias);

  /// Like [oneOf], but first converts to nanoseconds
  /// ([DateTime.microsecondsSinceEpoch] `* 1000`).
  Condition<EntityT> oneOfDate(List<DateTime> values, {String? alias}) =>
      oneOf(values.map(_convert).toList(), alias: alias);

  /// Like [notOneOf], but first converts to nanoseconds
  /// ([DateTime.microsecondsSinceEpoch] `* 1000`).
  Condition<EntityT> notOneOfDate(List<DateTime> values, {String? alias}) =>
      notOneOf(values.map(_convert).toList(), alias: alias);
}

/// For integer vectors (excluding [QueryByteVectorProperty]) greater, less and
/// equal are supported on elements of the vector (e.g. "has element greater").
class QueryIntegerVectorProperty<EntityT> extends QueryProperty<EntityT, int> {
  QueryIntegerVectorProperty(super.model);

  Condition<EntityT> _op(_ConditionOp cop, int p1, int p2, String? alias) =>
      _IntegerCondition<EntityT, int>(cop, this, p1, p2, alias);

  Condition<EntityT> equals(int p, {String? alias}) =>
      _op(_ConditionOp.eq, p, 0, alias);

  Condition<EntityT> greaterThan(int p, {String? alias}) =>
      _op(_ConditionOp.gt, p, 0, alias);

  Condition<EntityT> greaterOrEqual(int p, {String? alias}) =>
      _op(_ConditionOp.greaterOrEq, p, 0, alias);

  Condition<EntityT> lessThan(int p, {String? alias}) =>
      _op(_ConditionOp.lt, p, 0, alias);

  Condition<EntityT> lessOrEqual(int p, {String? alias}) =>
      _op(_ConditionOp.lessOrEq, p, 0, alias);

  Condition<EntityT> operator <(int p) => lessThan(p);

  Condition<EntityT> operator >(int p) => greaterThan(p);
}

class QueryDoubleProperty<EntityT> extends QueryProperty<EntityT, double> {
  QueryDoubleProperty(super.model);

  Condition<EntityT> _op(
          _ConditionOp op, double p1, double? p2, String? alias) =>
      _DoubleCondition<EntityT>(op, this, p1, p2, alias);

  /// Finds objects with property value between and including the first and second value.
  Condition<EntityT> between(double p1, double p2, {String? alias}) =>
      _op(_ConditionOp.between, p1, p2, alias);

  // NOTE: objectbox-c doesn't support double/float equality (because it's a
  // rather peculiar thing). Therefore, we're currently not providing this in
  // Dart either, not even with some `between()` workarounds.
  // Condition<EntityT> equals(double p) {
  //    _op(_ConditionOp.eq, p);
  // }

  Condition<EntityT> greaterThan(double p, {String? alias}) =>
      _op(_ConditionOp.gt, p, 0, alias);

  Condition<EntityT> greaterOrEqual(double p, {String? alias}) =>
      _op(_ConditionOp.greaterOrEq, p, null, alias);

  Condition<EntityT> lessThan(double p, {String? alias}) =>
      _op(_ConditionOp.lt, p, null, alias);

  Condition<EntityT> lessOrEqual(double p, {String? alias}) =>
      _op(_ConditionOp.lessOrEq, p, null, alias);

  Condition<EntityT> operator <(double p) => lessThan(p);

  Condition<EntityT> operator >(double p) => greaterThan(p);
}

/// For double vectors greater and less queries are supported on elements of
/// the vector (e.g. "has element greater").
class QueryDoubleVectorProperty<EntityT>
    extends QueryProperty<EntityT, double> {
  QueryDoubleVectorProperty(super.model);

  Condition<EntityT> _op(
          _ConditionOp op, double p1, double? p2, String? alias) =>
      _DoubleCondition<EntityT>(op, this, p1, p2, alias);

  Condition<EntityT> greaterThan(double p, {String? alias}) =>
      _op(_ConditionOp.gt, p, 0, alias);

  Condition<EntityT> greaterOrEqual(double p, {String? alias}) =>
      _op(_ConditionOp.greaterOrEq, p, null, alias);

  Condition<EntityT> lessThan(double p, {String? alias}) =>
      _op(_ConditionOp.lt, p, null, alias);

  Condition<EntityT> lessOrEqual(double p, {String? alias}) =>
      _op(_ConditionOp.lessOrEq, p, null, alias);

  Condition<EntityT> operator <(double p) => lessThan(p);

  Condition<EntityT> operator >(double p) => greaterThan(p);
}

/// Nearest neighbor search condition for use with [QueryHnswProperty].
class _NearestNeighborsCondition<EntityT> extends Condition<EntityT> {
  final QueryHnswProperty<EntityT> property;
  final List<double> queryVector;
  final int maxResultCount;

  _NearestNeighborsCondition(
      this.property, this.queryVector, this.maxResultCount, String? alias)
      : super(alias);

  @override
  int _apply(_QueryBuilder<dynamic> builder, {required bool isRoot}) =>
      withNativeFloats<int>(
          queryVector,
          (ptr, size) => C.qb_nearest_neighbors_f32(
              builder._cBuilder, property._model.id.id, ptr, maxResultCount));
}

/// Provides extra conditions for float vector properties with an [HnswIndex].
class QueryHnswProperty<EntityT> extends QueryDoubleVectorProperty<EntityT> {
  QueryHnswProperty(super.model);

  /// Performs an approximate nearest neighbor (ANN) search to find objects near to the given [queryVector].
  ///
  /// This requires the vector property to have an [HnswIndex].
  ///
  /// The dimensions of the query vector should be at least the dimensions of this vector property.
  ///
  /// Use [maxResultCount] to set the maximum number of objects to return by the ANN condition.
  /// Hint: it can also be used as the "ef" HNSW parameter to increase the search quality in combination with a
  /// query limit.
  /// For example, use maxResultCount of 100 with a [Query.limit] of 10 to have 10 results that are of potentially better quality
  /// than just passing in 10 for maxResultCount (quality/performance tradeoff).
  Condition<EntityT> nearestNeighborsF32(
          List<double> queryVector, int maxResultCount,
          {String? alias}) =>
      _NearestNeighborsCondition(this, queryVector, maxResultCount, alias);
}

class QueryBooleanProperty<EntityT> extends QueryProperty<EntityT, bool> {
  QueryBooleanProperty(super.model);

  // ignore: avoid_positional_boolean_parameters
  Condition<EntityT> equals(bool p, {String? alias}) =>
      _IntegerCondition<EntityT, bool>(
          _ConditionOp.eq, this, (p ? 1 : 0), null, alias);

  // ignore: avoid_positional_boolean_parameters
  Condition<EntityT> notEquals(bool p, {String? alias}) =>
      _IntegerCondition<EntityT, bool>(
          _ConditionOp.notEq, this, (p ? 1 : 0), null, alias);
}

class QueryStringVectorProperty<EntityT>
    extends QueryProperty<EntityT, List<String>> {
  QueryStringVectorProperty(super.model);

  /// Matches if at least one element of the list equals the given value.
  Condition<EntityT> containsElement(String value,
          {bool? caseSensitive, String? alias}) =>
      _StringCondition<EntityT, List<String>>(
          _ConditionOp.containsElement, this, value, null, alias,
          caseSensitive: caseSensitive);
}

class QueryRelationToOne<Source, Target> extends QueryIntegerProperty<Source> {
  QueryRelationToOne(super.model);
}

class QueryRelationToMany<Source, Target> {
  final ModelRelation _model;

  QueryRelationToMany(this._model);
}

class QueryBacklinkToMany<Source, Target> {
  late final int _relationPropertyId;

  QueryBacklinkToMany(QueryRelationToOne<Source, Target> relProp) {
    _relationPropertyId = relProp._model.id.id;
  }

  /// Creates a condition to match objects that have [relationCount] related
  /// objects pointing to them.
  ///
  /// ```
  /// // match customers with two orders
  /// box.query(Customer_.orders.relationCount(2));
  /// ```
  ///
  /// The relation count may be 0 to match objects that do not have any related
  /// objects. It typically should be a low number.
  ///
  /// This condition has some limitations:
  /// - only 1:N (ToMany using @Backlink) relations are supported,
  /// - the complexity is `O(n * (relationCount + 1))` and cannot be improved
  ///   via indexes,
  /// - the relation count cannot be changed with `param()` once the query is
  ///   built.
  Condition<Target> relationCount(int relationCount, {String? alias}) =>
      _RelationCountCondition<Source, Target>(
          _relationPropertyId, relationCount, alias);
}

enum _ConditionOp {
  isNull,
  notNull,
  eq,
  notEq,
  contains,
  containsElement,
  startsWith,
  endsWith,
  gt,
  greaterOrEq,
  lt,
  lessOrEq,
  oneOf,
  notOneOf,
  between,
}

/// A [Query] condition base class.
abstract class Condition<EntityT> {
  final String? _alias;

  Condition(this._alias);

  // using & because && is not overridable
  Condition<EntityT> operator &(Condition<EntityT> rh) => and(rh);

  Condition<EntityT> and(Condition<EntityT> rh) => andAll([rh]);

  Condition<EntityT> andAll(List<Condition<EntityT>> rh) =>
      _ConditionGroupAll<EntityT>((this is _ConditionGroupAll)
          // no need for brackets when merging same types
          ? [...(this as _ConditionGroupAll<EntityT>)._conditions, ...rh]
          : [this, ...rh]);

  // using | because || is not overridable
  Condition<EntityT> operator |(Condition<EntityT> rh) => or(rh);

  Condition<EntityT> or(Condition<EntityT> rh) => orAny([rh]);

  Condition<EntityT> orAny(List<Condition<EntityT>> rh) =>
      _ConditionGroupAny<EntityT>((this is _ConditionGroupAny)
          // no need for brackets when merging same types
          ? [...(this as _ConditionGroupAny<EntityT>)._conditions, ...rh]
          : [this, ...rh]);

  int _apply(_QueryBuilder builder, {required bool isRoot});

  int _applyFull(_QueryBuilder builder, {required bool isRoot}) {
    final cid = _apply(builder, isRoot: isRoot);
    if (cid == 0) builder._throwExceptionIfNecessary();
    if (_alias != null) {
      checkObx(withNativeString(_alias!,
          (Pointer<Char> cStr) => C.qb_param_alias(builder._cBuilder, cStr)));
    }
    return cid;
  }
}

class _NullCondition<EntityT, DartType> extends Condition<EntityT> {
  final QueryProperty<EntityT, DartType> _property;
  final _ConditionOp _op;

  _NullCondition(this._op, this._property, String? alias) : super(alias);

  @override
  int _apply(_QueryBuilder builder, {required bool isRoot}) {
    switch (_op) {
      case _ConditionOp.isNull:
        return C.qb_null(builder._cBuilder, _property._model.id.id);
      case _ConditionOp.notNull:
        return C.qb_not_null(builder._cBuilder, _property._model.id.id);
      default:
        throw UnsupportedError('Unsupported operation ${_op.toString()}');
    }
  }
}

/// See [QueryBacklinkToMany.relationCount].
class _RelationCountCondition<Source, Target> extends Condition<Target> {
  final int _relationPropertyId;
  final int _relationCount;

  _RelationCountCondition(
      this._relationPropertyId, this._relationCount, String? alias)
      : super(alias);

  @override
  int _apply(_QueryBuilder builder, {required bool isRoot}) {
    int relationEntityId =
        InternalStoreAccess.entityDef<Source>(builder._store).model.id.id;
    return C.qb_relation_count_property(builder._cBuilder, relationEntityId,
        _relationPropertyId, _relationCount);
  }
}

abstract class _PropertyCondition<EntityT, PropertyDartType, ValueDartType>
    extends Condition<EntityT> {
  final QueryProperty<EntityT, PropertyDartType> _property;
  final ValueDartType _value;
  final ValueDartType? _value2;

  final _ConditionOp _op;

  _PropertyCondition(
      this._op, this._property, this._value, this._value2, String? alias)
      : super(alias);
}

class _StringCondition<EntityT, PropertyDartType>
    extends _PropertyCondition<EntityT, PropertyDartType, String> {
  bool? caseSensitive;

  _StringCondition(super.op, super.prop, super.value, super.value2, super.alias,
      {this.caseSensitive});

  int _op1(_QueryBuilder builder,
      int Function(Pointer<OBX_query_builder>, int, Pointer<Char>, bool) func) {
    final cStr = _value.toNativeUtf8();
    try {
      return func(builder._cBuilder, _property._model.id.id, cStr.cast(),
          caseSensitive ?? InternalStoreAccess.queryCS(builder._store));
    } finally {
      malloc.free(cStr);
    }
  }

  @override
  int _apply(_QueryBuilder builder, {required bool isRoot}) {
    switch (_op) {
      case _ConditionOp.eq:
        return _op1(builder, C.qb_equals_string);
      case _ConditionOp.notEq:
        return _op1(builder, C.qb_not_equals_string);
      case _ConditionOp.contains:
        return _op1(builder, C.qb_contains_string);
      case _ConditionOp.containsElement:
        return _op1(builder, C.qb_contains_element_string);
      case _ConditionOp.startsWith:
        return _op1(builder, C.qb_starts_with_string);
      case _ConditionOp.endsWith:
        return _op1(builder, C.qb_ends_with_string);
      case _ConditionOp.lt:
        return _op1(builder, C.qb_less_than_string);
      case _ConditionOp.lessOrEq:
        return _op1(builder, C.qb_less_or_equal_string);
      case _ConditionOp.gt:
        return _op1(builder, C.qb_greater_than_string);
      case _ConditionOp.greaterOrEq:
        return _op1(builder, C.qb_greater_or_equal_string);
      default:
        throw UnsupportedError('Unsupported operation ${_op.toString()}');
    }
  }
}

class _StringListCondition<EntityT>
    extends _PropertyCondition<EntityT, String, List<String>> {
  bool? caseSensitive;

  _StringListCondition(_ConditionOp op, QueryProperty<EntityT, String> prop,
      List<String> value, String? alias,
      {this.caseSensitive})
      : super(op, prop, value, null, alias);

  int _oneOf(_QueryBuilder builder) => withNativeStrings(
      _value,
      (Pointer<Pointer<Char>> ptr, int size) => C.qb_in_strings(
          builder._cBuilder,
          _property._model.id.id,
          ptr,
          size,
          caseSensitive ?? InternalStoreAccess.queryCS(builder._store)));

  @override
  int _apply(_QueryBuilder builder, {required bool isRoot}) {
    switch (_op) {
      case _ConditionOp.oneOf:
        return _oneOf(builder); // bindings.obx_qb_string_in
      default:
        throw UnsupportedError('Unsupported operation ${_op.toString()}');
    }
  }
}

class _IntegerCondition<EntityT, PropertyDartType>
    extends _PropertyCondition<EntityT, PropertyDartType, int> {
  _IntegerCondition(
      super.op, super.prop, super.value, super.value2, super.alias);

  int _op1(_QueryBuilder builder,
          int Function(Pointer<OBX_query_builder>, int, int) func) =>
      func(builder._cBuilder, _property._model.id.id, _value);

  @override
  int _apply(_QueryBuilder builder, {required bool isRoot}) {
    switch (_op) {
      case _ConditionOp.eq:
        return _op1(builder, C.qb_equals_int);
      case _ConditionOp.notEq:
        return _op1(builder, C.qb_not_equals_int);
      case _ConditionOp.gt:
        return _op1(builder, C.qb_greater_than_int);
      case _ConditionOp.greaterOrEq:
        return _op1(builder, C.qb_greater_or_equal_int);
      case _ConditionOp.lt:
        return _op1(builder, C.qb_less_than_int);
      case _ConditionOp.lessOrEq:
        return _op1(builder, C.qb_less_or_equal_int);
      case _ConditionOp.between:
        return C.qb_between_2ints(
            builder._cBuilder, _property._model.id.id, _value, _value2!);
      default:
        throw UnsupportedError('Unsupported operation ${_op.toString()}');
    }
  }
}

class _IntegerListCondition<EntityT>
    extends _PropertyCondition<EntityT, int, List<int>> {
  _IntegerListCondition(_ConditionOp op, QueryProperty<EntityT, int> prop,
      List<int> value, String? alias)
      : super(op, prop, value, null, alias);

  int _opList<T extends NativeType>(
      _QueryBuilder builder,
      Pointer<T> listPtr,
      int Function(Pointer<OBX_query_builder>, int, Pointer<T>, int) func,
      void Function(Pointer<T>, int, int) setIndex) {
    final length = _value.length;
    try {
      for (var i = 0; i < length; i++) {
        // Error: The operator '[]=' isn't defined for the type 'Pointer<T>
        // listPtr[i] = _list[i];
        setIndex(listPtr, i, _value[i]);
      }
      return func(builder._cBuilder, _property._model.id.id, listPtr, length);
    } finally {
      malloc.free(listPtr);
    }
  }

  static void opListSetIndexInt32(Pointer<Int32> list, int i, int val) =>
      list[i] = val;

  static void opListSetIndexInt64(Pointer<Int64> list, int i, int val) =>
      list[i] = val;

  @override
  int _apply(_QueryBuilder builder, {required bool isRoot}) {
    switch (_op) {
      case _ConditionOp.oneOf:
        switch (_property._model.type) {
          case OBXPropertyType.Int:
            return _opList(builder, malloc<Int32>(_value.length),
                C.qb_in_int32s, opListSetIndexInt32);
          case OBXPropertyType.Long:
          case OBXPropertyType.Date:
          case OBXPropertyType.DateNano:
            return _opList(builder, malloc<Int64>(_value.length),
                C.qb_in_int64s, opListSetIndexInt64);
          default:
            throw UnsupportedError(
                'Unsupported type for IN: ${_property._model.type}');
        }
      case _ConditionOp.notOneOf:
        switch (_property._model.type) {
          case OBXPropertyType.Int:
            return _opList(builder, malloc<Int32>(_value.length),
                C.qb_not_in_int32s, opListSetIndexInt32);
          case OBXPropertyType.Long:
          case OBXPropertyType.Date:
          case OBXPropertyType.DateNano:
            return _opList(builder, malloc<Int64>(_value.length),
                C.qb_not_in_int64s, opListSetIndexInt64);
          default:
            throw UnsupportedError(
                'Unsupported type for IN: ${_property._model.type}');
        }
      default:
        throw UnsupportedError('Unsupported operation ${_op.toString()}');
    }
  }
}

class _DoubleCondition<EntityT>
    extends _PropertyCondition<EntityT, double, double> {
  _DoubleCondition(_ConditionOp op, QueryProperty<EntityT, double> prop,
      double value, double? value2, String? alias)
      : super(op, prop, value, value2, alias) {
    assert(op != _ConditionOp.eq,
        'Equality operator is not supported on floating point numbers - use between() instead.');
  }

  @override
  int _apply(_QueryBuilder builder, {required bool isRoot}) {
    switch (_op) {
      case _ConditionOp.gt:
        return C.qb_greater_than_double(
            builder._cBuilder, _property._model.id.id, _value);
      case _ConditionOp.greaterOrEq:
        return C.qb_greater_or_equal_double(
            builder._cBuilder, _property._model.id.id, _value);
      case _ConditionOp.lt:
        return C.qb_less_than_double(
            builder._cBuilder, _property._model.id.id, _value);
      case _ConditionOp.lessOrEq:
        return C.qb_less_or_equal_double(
            builder._cBuilder, _property._model.id.id, _value);
      case _ConditionOp.between:
        return C.qb_between_2doubles(
            builder._cBuilder, _property._model.id.id, _value, _value2!);
      default:
        throw UnsupportedError('Unsupported operation ${_op.toString()}');
    }
  }
}

class _ByteVectorCondition<EntityT>
    extends _PropertyCondition<EntityT, Uint8List, Uint8List> {
  _ByteVectorCondition(_ConditionOp op, QueryProperty<EntityT, Uint8List> prop,
      Uint8List value, String? alias)
      : super(op, prop, value, null, alias);

  int _op1(
          _QueryBuilder builder,
          int Function(Pointer<OBX_query_builder>, int, Pointer<Uint8>, int)
              func) =>
      withNativeBytes(
          _value,
          (Pointer<Uint8> ptr, int size) =>
              func(builder._cBuilder, _property._model.id.id, ptr, size));

  @override
  int _apply(_QueryBuilder builder, {required bool isRoot}) {
    switch (_op) {
      case _ConditionOp.eq:
        return _op1(builder, C.qb_equals_bytes);
      case _ConditionOp.lt:
        return _op1(builder, C.qb_less_than_bytes);
      case _ConditionOp.lessOrEq:
        return _op1(builder, C.qb_less_or_equal_bytes);
      case _ConditionOp.gt:
        return _op1(builder, C.qb_greater_than_bytes);
      case _ConditionOp.greaterOrEq:
        return _op1(builder, C.qb_greater_or_equal_bytes);
      default:
        throw UnsupportedError('Unsupported operation ${_op.toString()}');
    }
  }
}

class _ConditionGroup<EntityT> extends Condition<EntityT> {
  final List<Condition<EntityT>> _conditions;
  final int Function(Pointer<OBX_query_builder>, Pointer<Int>, int) _func;

  _ConditionGroup(this._conditions, this._func) : super(null);

  @override
  int _apply(_QueryBuilder builder, {required bool isRoot}) {
    final size = _conditions.length;

    if (size == 0) {
      return -1; // -1 instead of 0 which indicates an error
    } else if (size == 1) {
      return _conditions[0]._applyFull(builder, isRoot: isRoot);
    }

    final intArrayPtr = malloc<Int>(size);
    try {
      for (var i = 0; i < size; ++i) {
        final cid = _conditions[i]._applyFull(builder, isRoot: false);
        if (cid == 0) {
          builder._throwExceptionIfNecessary();
          throw StateError('Failed to create condition ${_conditions[i]}');
        }

        intArrayPtr[i] = cid;
      }

      // root All (AND) is implicit so no need to actually combine the conditions
      if (isRoot && this is _ConditionGroupAll) {
        return -1; // no error but no condition ID either
      }

      return _func(builder._cBuilder, intArrayPtr, size);
    } finally {
      malloc.free(intArrayPtr);
    }
  }
}

class _ConditionGroupAny<EntityT> extends _ConditionGroup<EntityT> {
  _ConditionGroupAny(List<Condition<EntityT>> conditions)
      : super(conditions, C.qb_any);
}

class _ConditionGroupAll<EntityT> extends _ConditionGroup<EntityT> {
  _ConditionGroupAll(List<Condition<EntityT>> conditions)
      : super(conditions, C.qb_all);
}

/// A repeatable Query returning the latest matching Objects.
///
/// Use [find] or related methods to fetch the latest results from the Box.
///
/// Use [property] to only return values or an aggregate of a single Property.
class Query<T> implements Finalizable {
  bool _closed = false;

  /// Pointer to the native instance. Use [_ptr] for safe access instead.
  final Pointer<OBX_query> _cQuery;

  /// Runs native close function on [_cQuery] if this is garbage collected.
  ///
  /// Keeps the finalizer itself reachable (static), otherwise it might be
  /// disposed of before the finalizer callback gets a chance to run.
  static final _finalizer = NativeFinalizer(C.addresses.query_close.cast());

  final Store _store;
  final EntityDefinition<T> _entity;

  int get entityId => _entity.model.id.id;

  Query._(this._store, Pointer<OBX_query_builder> cBuilder, this._entity)
      : _cQuery = checkObxPtr(C.query(cBuilder), 'create query') {
    initializeDartAPI();
    _attachFinalizer();
  }

  Query._fromConfiguration(this._store, _QueryConfiguration<T> configuration)
      : _cQuery = Pointer.fromAddress(configuration.queryAddress),
        _entity = configuration.entity {
    initializeDartAPI();
    _attachFinalizer();
  }

  void _attachFinalizer() {
    _finalizer.attach(this, _cQuery.cast(), detach: this, externalSize: 256);
  }

  @pragma("vm:prefer-inline")
  Pointer<OBX_query> get _ptr {
    _checkOpen();
    return _cQuery;
  }

  void _checkOpen() {
    // Throw an exception instead of crashing by checking if the store is open.
    _store.checkOpen();
    if (_closed) {
      throw StateError('Query already closed, cannot execute any actions');
    }
  }

  /// If greater than 0, Query methods will skip [offset] number of results.
  ///
  /// Use together with [limit] to get a slice of the whole result, e.g. for "result paging".
  set offset(int offset) => checkObx(C.query_offset(_ptr, offset));

  /// If greater than 0, Query methods will return at most [limit] many results.
  ///
  /// Use together with [offset] to get a slice of the whole result, e.g. for "result paging".
  set limit(int limit) => checkObx(C.query_limit(_ptr, limit));

  /// Returns the number of matching Objects.
  int count() {
    final ptr = malloc<Uint64>();
    try {
      checkObx(C.query_count(_ptr, ptr));
      return ptr.value;
    } finally {
      malloc.free(ptr);
    }
  }

  /// Removes all matching objects. Returns the number of removed objects.
  int remove() {
    final ptr = malloc<Uint64>();
    try {
      checkObx(C.query_remove(_ptr, ptr));
      return ptr.value;
    } finally {
      malloc.free(ptr);
    }
  }

  // Static callback to avoid over-capturing due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983).
  static int _removeAsyncCallback<T>(
          Store store, _QueryConfiguration<T> configuration) =>
      _asyncCallbackImpl<T, int>(
          store, configuration, (query) => query.remove());

  /// Like [remove], but runs in a worker isolate.
  Future<int> removeAsync() => _runAsyncImpl(_removeAsyncCallback<T>);

  /// Clones this native query and returns a pointer to the clone.
  ///
  /// This is useful to send a reference to a query to an isolate. A [Query] can
  /// not be sent to an isolate directly because it contains pointers.
  ///
  /// ```dart
  /// // Clone the query and obtain its address, can be sent to an isolate.
  /// final queryPtrAddress = query._clone().address;
  ///
  /// // Within an isolate re-create the query pointer to be used with the C API.
  /// final queryPtr = Pointer<OBX_query>.fromAddress(isolateInit.queryPtrAddress);
  /// ```
  Pointer<OBX_query> _clone() => checkObxPtr(C.query_clone(_ptr));

  /// Close the query and free resources.
  void close() {
    if (!_closed) {
      _closed = true;
      _finalizer.detach(this);
      checkObx(C.query_close(_cQuery));
    }
  }

  /// Finds the first object matching this query.
  ///
  /// Returns `null` if no object matches.
  ///
  /// Note: if no [QueryBuilder.order] conditions are present, which object is the first one
  /// might be arbitrary (sometimes the one with the lowest ID, but never guaranteed to be).
  T? findFirst() {
    T? result;
    final errorWrapper = ObjectVisitorError();
    visitCallBack(Pointer<Uint8> data, int size) {
      try {
        result = _entity.objectFromData(_store, data, size);
      } catch (e) {
        errorWrapper.error = e;
      }
      return false; // we only want to visit the first element
    }

    visit(_ptr, visitCallBack);
    errorWrapper.throwIfError();
    return result;
  }

  // Static callback to avoid over-capturing due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983).
  static T? _findFirstAsyncCallback<T>(
          Store store, _QueryConfiguration<T> configuration) =>
      _asyncCallbackImpl<T, T?>(
          store, configuration, (query) => query.findFirst());

  /// Like [findFirst], but runs the query operation asynchronously in a worker
  /// isolate.
  Future<T?> findFirstAsync() => _runAsyncImpl(_findFirstAsyncCallback<T>);

  /// Finds the only object matching this query.
  ///
  /// Returns the object if a single object matches. `null` if no object matches.
  /// Throws [NonUniqueResultException] if there are multiple objects matching the query.
  ///
  /// Note: Because [limit] affects the number of matched objects, make sure to leave it
  /// at zero or set it higher than one, otherwise the check for non-unique result won't work.
  T? findUnique() {
    T? result;
    final errorWrapper = ObjectVisitorError();
    visitCallback(Pointer<Uint8> data, int size) {
      if (result == null) {
        try {
          result = _entity.objectFromData(_store, data, size);
          return true;
        } catch (e) {
          errorWrapper.error = e;
          return false;
        }
      } else {
        errorWrapper.error = NonUniqueResultException(
            'Query findUnique() matched more than one object');
        return false;
      }
    }

    visit(_ptr, visitCallback);
    errorWrapper.throwIfError();
    return result;
  }

  // Static callback to avoid over-capturing due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983).
  static T? _findUniqueAsyncCallback<T>(
          Store store, _QueryConfiguration<T> configuration) =>
      _asyncCallbackImpl<T, T?>(
          store, configuration, (query) => query.findUnique());

  /// Like [findUnique], but runs the query operation asynchronously in a worker
  /// isolate.
  Future<T?> findUniqueAsync() => _runAsyncImpl(_findUniqueAsyncCallback<T>);

  /// Like [find], but returns just the IDs of the objects.
  ///
  /// Returns a list of IDs of matching objects. An empty array if no objects match.
  ///
  /// IDs can later be used to [Box.get] objects.
  ///
  /// This is very efficient as no objects are created.
  List<int> findIds() {
    final idArrayPtr = checkObxPtr(C.query_find_ids(_ptr), 'find ids');
    try {
      final idArray = idArrayPtr.ref;
      final ids = idArray.ids;
      return List.generate(idArray.count, (i) => ids[i], growable: false);
    } finally {
      C.id_array_free(idArrayPtr);
    }
  }

  // Static callback to avoid over-capturing due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983).
  static List<int> _findIdsAsyncCallback<T>(
          Store store, _QueryConfiguration<T> configuration) =>
      _asyncCallbackImpl<T, List<int>>(
          store, configuration, (query) => query.findIds());

  /// Like [findIds], but runs the query operation asynchronously in a worker
  /// isolate.
  Future<List<int>> findIdsAsync() => _runAsyncImpl(_findIdsAsyncCallback<T>);

  /// Finds objects matching the query.
  ///
  /// Returns a list of matching objects. An empty list if no object matches.
  ///
  /// Note: if no [QueryBuilder.order] conditions are present, the order is arbitrary
  /// (sometimes ordered by ID, but never guaranteed to).
  List<T> find() {
    final result = <T>[];
    final errorWrapper = ObjectVisitorError();
    visitCallback(Pointer<Uint8> data, int size) {
      try {
        result.add(_entity.objectFromData(_store, data, size));
        return true;
      } catch (e) {
        errorWrapper.error = e;
        return false;
      }
    }

    visit(_ptr, visitCallback);
    errorWrapper.throwIfError();
    return result;
  }

  // Static callback to avoid over-capturing due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983).
  static List<T> _findAsyncCallback<T>(
          Store store, _QueryConfiguration<T> configuration) =>
      _asyncCallbackImpl<T, List<T>>(
          store, configuration, (query) => query.find());

  /// Like [find], but runs the query operation asynchronously in a worker
  /// isolate.
  Future<List<T>> findAsync() => _runAsyncImpl(_findAsyncCallback<T>);

  /// Finds IDs of objects matching the query associated to their query score (e. g. distance in NN search).
  ///
  /// Returns a list of [IdWithScore] that wraps IDs of matching objects and their score,
  /// sorted by score in ascending order.
  ///
  /// This only works on objects with a property with an [HnswIndex].
  List<IdWithScore> findIdsWithScores() {
    final resultPtr = checkObxPtr(C.query_find_ids_with_scores(_ptr));
    try {
      final items = resultPtr.ref.ids_scores;
      final count = resultPtr.ref.count;
      return List.generate(count, (i) {
        // items[i] only available with Dart 3.3
        final item = (items + i).ref;
        final id = item.id;
        final score = item.score;
        return IdWithScore(id, score);
      }, growable: false);
    } finally {
      C.id_score_array_free(resultPtr);
    }
  }

  /// Like [findIdsWithScores], but runs the query operation asynchronously in a
  /// worker isolate.
  Future<List<IdWithScore>> findIdsWithScoresAsync() =>
      _runAsyncImpl(_findIdsWithScoresAsyncCallback<T>);

  // Static callback to avoid over-capturing due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983).
  static List<IdWithScore> _findIdsWithScoresAsyncCallback<T>(
          Store store, _QueryConfiguration<T> configuration) =>
      _asyncCallbackImpl<T, List<IdWithScore>>(
          store, configuration, (query) => query.findIdsWithScores());

  /// Finds objects matching the query associated to their query score (e. g. distance in NN search).
  /// The resulting list is sorted by score in ascending order.
  ///
  /// Returns a list of [ObjectWithScore] that matching objects and their score,
  /// sorted by score in ascending order.
  ///
  /// This only works on objects with a property with an [HnswIndex].
  List<ObjectWithScore<T>> findWithScores() {
    final result = <ObjectWithScore<T>>[];
    final errorWrapper = ObjectVisitorError();
    visitCallback(Pointer<OBX_bytes_score> data) {
      try {
        final item = data.ref;
        final object = _entity.objectFromData(_store, item.data, item.size);
        final score = item.score;
        result.add(ObjectWithScore(object, score));
        return true;
      } catch (e) {
        errorWrapper.error = e;
        return false;
      }
    }

    visitWithScore(_ptr, visitCallback);
    errorWrapper.throwIfError();
    return result;
  }

  /// Like [findWithScores], but runs the query operation asynchronously in a
  /// worker isolate.
  Future<List<ObjectWithScore<T>>> findWithScoresAsync() =>
      _runAsyncImpl(_findWithScoresAsyncCallback<T>);

  // Static callback to avoid over-capturing due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983).
  static List<ObjectWithScore<T>> _findWithScoresAsyncCallback<T>(
          Store store, _QueryConfiguration<T> configuration) =>
      _asyncCallbackImpl<T, List<ObjectWithScore<T>>>(
          store, configuration, (query) => query.findWithScores());

  /// Base callback for [_runAsyncImpl] to run a query [action] in a worker
  /// isolate.
  ///
  /// Static callback to avoid over-capturing due to [dart-lang/sdk#36983](https://github.com/dart-lang/sdk/issues/36983).
  static R _asyncCallbackImpl<T, R>(Store store,
      _QueryConfiguration<T> configuration, R Function(Query<T>) action) {
    final query = Query._fromConfiguration(store, configuration);
    try {
      return action(query);
    } finally {
      query.close();
    }
  }

  /// Runs the given query callback on a worker isolate and returns the result,
  /// clones the query to pass it to the worker isolate
  /// (see [_QueryConfiguration]).
  Future<R> _runAsyncImpl<R>(
          R Function(Store, _QueryConfiguration<T>) callback) =>
      _store.runAsync(callback, _QueryConfiguration(this));

  /// Finds Objects matching the query, streaming them while the query executes.
  ///
  /// Results are streamed from a worker isolate in batches (the stream still
  /// returns objects one by one).
  Stream<T> stream() => _streamIsolate();

  /// Stream items by sending full flatbuffers binary as a message.
  /// Replaced by _streamIsolate which in benchmarks has been faster.
  // Stream<T> _stream1() {
  //   initializeDartAPI();
  //   final port = ReceivePort();
  //   final cStream = checkObxPtr(
  //       C.dartc_query_find(_cQuery, port.sendPort.nativePort), 'query stream');
  //
  //   var closed = false;
  //   final close = () {
  //     if (closed) return;
  //     closed = true;
  //     C.dartc_stream_close(cStream);
  //     port.close();
  //   };
  //
  //   try {
  //     final controller = StreamController<T>(onCancel: close);
  //     port.listen((dynamic message) {
  //       // We expect Uint8List for data and NULL when the query has finished.
  //       if (message is Uint8List) {
  //         try {
  //           controller.add(
  //               _entity.objectFromFB(_store, ByteData.view(message.buffer)));
  //           return;
  //         } catch (e) {
  //           controller.addError(e);
  //         }
  //       } else if (message is String) {
  //         controller.addError(
  //             ObjectBoxException('Query stream native exception: $message'));
  //       } else if (message != null) {
  //         controller.addError(ObjectBoxException(
  //             'Query stream received an invalid message type '
  //             '(${message.runtimeType}): $message'));
  //       }
  //       // Close the stream, this will call the onCancel function.
  //       // Do not call the onCancel function manually,
  //       // if cancel() is called on the Stream subscription right afterwards it
  //       // will use the shortcut in the onCancel function and not wait.
  //       controller.close(); // done
  //     });
  //     return controller.stream;
  //   } catch (e) {
  //     close();
  //     rethrow;
  //   }
  // }

  /// Stream items by sending pointers from native code.
  /// Interestingly this is slower even though it transfers only pointers...
  /// Probably because of the slowness of `asTypedList()`, see native_pointers.dart benchmark
  // Stream<T> _stream2() {
  //   initializeDartAPI();
  //   final port = ReceivePort();
  //   final cStream = checkObxPtr(
  //       C.dartc_query_find_ptr(_cQuery, port.sendPort.nativePort),
  //       'query stream');
  //
  //   var closed = false;
  //   final close = () {
  //     if (closed) return;
  //     closed = true;
  //     C.dartc_stream_close(cStream);
  //     port.close();
  //   };
  //
  //   try {
  //     final controller = StreamController<T>(onCancel: close);
  //     port.listen((dynamic message) {
  //       // We expect Uint8List for data and NULL when the query has finished.
  //       if (message is Uint8List) {
  //         try {
  //           final int64s = Int64List.view(message.buffer);
  //           assert(int64s.length == 2);
  //           final data =
  //               Pointer<Uint8>.fromAddress(int64s[0]).asTypedList(int64s[1]);
  //           controller.add(_entity.objectFromFB(_store, data));
  //           return;
  //         } catch (e) {
  //           controller.addError(e);
  //         }
  //       } else if (message is String) {
  //         controller.addError(
  //             ObjectBoxException('Query stream native exception: $message'));
  //       } else if (message != null) {
  //         controller.addError(ObjectBoxException(
  //             'Query stream received an invalid message type '
  //             '(${message.runtimeType}): $message'));
  //       }
  //       controller.close(); // done
  //       close();
  //     });
  //     return controller.stream;
  //   } catch (e) {
  //     close();
  //     rethrow;
  //   }
  // }

  Stream<T> _streamIsolate() {
    final resultPort = ReceivePort();
    final exitPort = ReceivePort();

    void spawnWorkerIsolate() async {
      // Pass clones of Store and Query to avoid these getting closed while the
      // worker isolate is still running. The isolate closes the clones once done.
      final storeClonePtr = InternalStoreAccess.clone(_store);
      final queryClonePtr = _clone();

      // Current batch size determined through testing, performs well for smaller
      // objects. Might want to expose in the future for performance tuning by
      // users.
      final isolateInit = _StreamIsolateInit(resultPort.sendPort,
          storeClonePtr.address, queryClonePtr.address, 20);
      // If spawn errors StreamController will propagate the error, no point in
      // using addError as no listener before this function completes.
      await Isolate.spawn(_queryAndVisit, isolateInit,
          onExit: exitPort.sendPort);
    }

    SendPort? sendPort;

    // Callback to exit the isolate once consumers or this close the stream
    // (potentially before all results have been streamed).
    // Must return Future<void>, otherwise StreamController will not wait on it.
    var isolateExitSent = false;
    Future<void> exitIsolate() async {
      if (isolateExitSent) return;
      isolateExitSent = true;
      // Send signal to isolate it should exit.
      sendPort?.send(null);
      // Wait for isolate to clean up native resources,
      // otherwise e.g. Store is still open and
      // e.g. tests can not delete database files.
      await exitPort.first;
      resultPort.close();
      exitPort.close();
    }

    final streamController = StreamController<T>(
        onListen: spawnWorkerIsolate, onCancel: exitIsolate);
    resultPort.listen((dynamic message) async {
      // The first message from the spawned isolate is a SendPort. This port
      // is used to communicate with the spawned isolate.
      if (message is SendPort) {
        sendPort = message;
        return; // wait for next message.
      }
      // Further messages are
      // - ObxObjectMessage for data,
      // - Exception and Error for errors and
      // - null if the worker isolate is done sending data.
      else if (message is _StreamIsolateMessage) {
        try {
          for (var i = 0; i < message.dataPtrAddresses.length; i++) {
            final dataPtrAddress = message.dataPtrAddresses[i];
            final size = message.sizes[i];
            if (size == 0) break; // Reached last object.
            streamController.add(_entity.objectFromData(
                _store, Pointer.fromAddress(dataPtrAddress), size));
          }
          return; // wait for next message.
        } catch (e) {
          streamController.addError(e);
        }
      } else if (message is Error) {
        streamController.addError(message);
      } else if (message is Exception) {
        streamController.addError(message);
      } else if (message != null) {
        streamController.addError(
            ObjectBoxException('Query stream received an invalid message type '
                '(${message.runtimeType}): $message'));
      }
      // Close the stream, this will call the onCancel function.
      // Do not call the onCancel function manually,
      // if cancel() is called on the Stream subscription right afterwards it
      // will use the shortcut in the onCancel function and not wait.
      streamController.close();
    });
    return streamController.stream;
  }

  // Isolate entry point must be top-level or static.
  static Future<void> _queryAndVisit(_StreamIsolateInit isolateInit) async {
    // Init native resources asap so that they do not leak, e.g. on exceptions
    final store =
        InternalStoreAccess.createMinimal(isolateInit.storePtrAddress);

    var resultPort = isolateInit.resultPort;

    // Send a SendPort to the main isolate so that it can send to this isolate.
    final commandPort = ReceivePort();
    resultPort.send(commandPort.sendPort);

    try {
      // Visit inside transaction and do not complete transaction to ensure
      // data pointers remain valid until main isolate has deserialized all data.
      await InternalStoreAccess.runInTransaction(store, TxMode.read,
          (Transaction tx) async {
        // Use fixed-length lists to avoid performance hit due to growing.
        final maxBatchSize = isolateInit.batchSize;
        var dataPtrBatch = List<int>.filled(maxBatchSize, 0);
        var sizeBatch = List<int>.filled(maxBatchSize, 0);
        var batchSize = 0;
        visitCallback(Pointer<Uint8> data, int size) {
          // Currently returning all results, even if the stream has been closed
          // before (e.g. only first element taken). Would need a way to check
          // for exit command on commandPort synchronously.
          dataPtrBatch[batchSize] = data.address;
          sizeBatch[batchSize] = size;
          batchSize++;
          // Send data in batches as sending a message is rather expensive.
          if (batchSize == maxBatchSize) {
            resultPort.send(_StreamIsolateMessage(dataPtrBatch, sizeBatch));
            // Re-use list instance to avoid performance hit due to new instance.
            dataPtrBatch.fillRange(0, dataPtrBatch.length, 0);
            sizeBatch.fillRange(0, dataPtrBatch.length, 0);
            batchSize = 0;
          }
          return true;
        }

        final queryPtr =
            Pointer<OBX_query>.fromAddress(isolateInit.queryPtrAddress);
        try {
          visit(queryPtr, visitCallback);
        } catch (e) {
          resultPort.send(e);
          return;
        } finally {
          try {
            checkObx(C.query_close(queryPtr));
          } catch (e) {
            resultPort.send(e);
            return;
          }
        }
        // Send any remaining data.
        if (batchSize > 0) {
          resultPort.send(_StreamIsolateMessage(dataPtrBatch, sizeBatch));
        }

        // Signal to the main isolate there are no more results.
        resultPort.send(null);
        // Wait for main isolate to confirm it is done accessing sent data pointers.
        await commandPort.first;
        // Note: when the transaction is closed after await this might lead to an
        // error log as the isolate could have been transferred to another thread
        // when resuming execution.
        // https://github.com/dart-lang/sdk/issues/46943
      });
    } finally {
      store.close();
      commandPort.close();
    }
  }

  /// For internal testing purposes.
  String describe() => dartStringFromC(C.query_describe(_ptr));

  /// For internal testing purposes.
  String describeParameters() => dartStringFromC(C.query_describe_params(_ptr));

  /// Use the same query conditions but only return a single property (field).
  ///
  /// Note: currently doesn't support [QueryBuilder.order] and always returns
  /// results in the order defined by the ID property.
  ///
  /// ```dart
  /// var results = query.property(tInteger).find();
  /// ```
  PropertyQuery<DartType> property<DartType>(QueryProperty<T, DartType> prop) {
    final result = PropertyQuery<DartType>._(
        this, C.query_prop(_ptr, prop._model.id.id), prop._model.type);
    if (prop._model.type == OBXPropertyType.String) {
      result._caseSensitive = InternalStoreAccess.queryCS(_store);
    }
    return result;
  }
}

/// Message passed to entry point [Query._queryAndVisit] of isolate.
@immutable
class _StreamIsolateInit {
  final SendPort resultPort;
  final int storePtrAddress;
  final int queryPtrAddress;
  final int batchSize;

  const _StreamIsolateInit(this.resultPort, this.storePtrAddress,
      this.queryPtrAddress, this.batchSize);
}

/// Message sent to main isolate containing info about a batch of objects.
@immutable
class _StreamIsolateMessage {
  final List<int> dataPtrAddresses;
  final List<int> sizes;

  const _StreamIsolateMessage(this.dataPtrAddresses, this.sizes);
}

class _QueryConfiguration<T> {
  final int queryAddress;
  final EntityDefinition<T> entity;

  /// Creates a configuration to send to an isolate by cloning the native query.
  _QueryConfiguration(Query<T> query)
      : queryAddress = query._clone().address,
        entity = query._entity;
}
