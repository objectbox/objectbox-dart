/// Web implementation of queries (phase 3 of web support, #185): a pure-Dart
/// evaluator over the Condition tree, running against the records of the web
/// engine (see engine.dart). Property values are read generically from the
/// stored FlatBuffers via fb_reader.dart.
///
/// Semantics follow the native implementation: string conditions default to
/// the store's queriesCaseSensitiveDefault, null property values only match
/// isNull, ordering defaults to ascending by id, string ordering is
/// case-insensitive unless Order.caseSensitive is set, and nearest-neighbor
/// (HNSW) conditions are evaluated as an exact brute-force scan ordered by
/// score. Not supported on web: Order.unsigned beyond 2^53 precision and Geo
/// vector distance.
///
/// Note for maintainers: this file imports the web sibling 'store.dart'
/// directly (the analyzer resolves conditional facades to the native variant)
/// and silences analyzer-only type mismatches at shared-code boundaries with
/// `// ignore: argument_type_not_assignable` - at web compile time the types
/// are identical.
// ignore_for_file: public_member_api_docs
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import '../common.dart';
import '../modelinfo/index.dart';
import '../vector_search_results.dart';
import 'engine.dart';
import 'fb_reader.dart';
import 'store.dart';

/// Groups query order flags.
class Order {
  static final descending = 1;

  static final caseSensitive = 2;

  static final unsigned = 4;

  static final nullsLast = 8;

  static final nullsAsZero = 16;
}

class QueryProperty<EntityT, DartType> {
  final ModelProperty _model;

  QueryProperty(ModelProperty model) : _model = model;

  Condition<EntityT> isNull({String? alias}) =>
      _PropCondition<EntityT>(_model, _Op.isNull, alias);

  Condition<EntityT> notNull({String? alias}) =>
      _PropCondition<EntityT>(_model, _Op.notNull, alias);
}

class QueryStringProperty<EntityT> extends QueryProperty<EntityT, String> {
  QueryStringProperty(super.model);

  Condition<EntityT> _cond(
          _Op op, String p, bool? caseSensitive, String? alias) =>
      _PropCondition<EntityT>(_model, op, alias,
          value: p, caseSensitive: caseSensitive);

  Condition<EntityT> equals(String p, {bool? caseSensitive, String? alias}) =>
      _cond(_Op.eq, p, caseSensitive, alias);

  Condition<EntityT> notEquals(String p,
          {bool? caseSensitive, String? alias}) =>
      _cond(_Op.notEq, p, caseSensitive, alias);

  Condition<EntityT> endsWith(String p, {bool? caseSensitive, String? alias}) =>
      _cond(_Op.endsWith, p, caseSensitive, alias);

  Condition<EntityT> startsWith(String p,
          {bool? caseSensitive, String? alias}) =>
      _cond(_Op.startsWith, p, caseSensitive, alias);

  Condition<EntityT> contains(String p, {bool? caseSensitive, String? alias}) =>
      _cond(_Op.contains, p, caseSensitive, alias);

  Condition<EntityT> oneOf(List<String> list,
          {bool? caseSensitive, String? alias}) =>
      _PropCondition<EntityT>(_model, _Op.oneOf, alias,
          list: List<Object?>.of(list), caseSensitive: caseSensitive);

  Condition<EntityT> greaterThan(String p,
          {bool? caseSensitive, String? alias}) =>
      _cond(_Op.gt, p, caseSensitive, alias);

  Condition<EntityT> greaterOrEqual(String p,
          {bool? caseSensitive, String? alias}) =>
      _cond(_Op.goe, p, caseSensitive, alias);

  Condition<EntityT> lessThan(String p, {bool? caseSensitive, String? alias}) =>
      _cond(_Op.lt, p, caseSensitive, alias);

  Condition<EntityT> lessOrEqual(String p,
          {bool? caseSensitive, String? alias}) =>
      _cond(_Op.loe, p, caseSensitive, alias);
}

class QueryByteVectorProperty<EntityT>
    extends QueryProperty<EntityT, Uint8List> {
  QueryByteVectorProperty(super.model);

  Condition<EntityT> _cond(_Op op, List<int> val, String? alias) =>
      _PropCondition<EntityT>(_model, op, alias, value: val);

  Condition<EntityT> equals(List<int> val, {String? alias}) =>
      _cond(_Op.eq, val, alias);

  Condition<EntityT> greaterThan(List<int> val, {String? alias}) =>
      _cond(_Op.gt, val, alias);

  Condition<EntityT> greaterOrEqual(List<int> val, {String? alias}) =>
      _cond(_Op.goe, val, alias);

  Condition<EntityT> lessThan(List<int> val, {String? alias}) =>
      _cond(_Op.lt, val, alias);

  Condition<EntityT> lessOrEqual(List<int> val, {String? alias}) =>
      _cond(_Op.loe, val, alias);
}

class QueryIntegerProperty<EntityT> extends QueryProperty<EntityT, int> {
  QueryIntegerProperty(super.model);

  Condition<EntityT> _cond(_Op op, int p, String? alias) =>
      _PropCondition<EntityT>(_model, op, alias, value: p);

  Condition<EntityT> equals(int p, {String? alias}) => _cond(_Op.eq, p, alias);

  Condition<EntityT> notEquals(int p, {String? alias}) =>
      _cond(_Op.notEq, p, alias);

  Condition<EntityT> greaterThan(int p, {String? alias}) =>
      _cond(_Op.gt, p, alias);

  Condition<EntityT> greaterOrEqual(int p, {String? alias}) =>
      _cond(_Op.goe, p, alias);

  Condition<EntityT> lessThan(int p, {String? alias}) =>
      _cond(_Op.lt, p, alias);

  Condition<EntityT> lessOrEqual(int p, {String? alias}) =>
      _cond(_Op.loe, p, alias);

  Condition<EntityT> operator <(int p) => lessThan(p);

  Condition<EntityT> operator >(int p) => greaterThan(p);

  /// Finds objects with property value between and including the first and second value.
  Condition<EntityT> between(int p1, int p2, {String? alias}) =>
      _PropCondition<EntityT>(_model, _Op.between, alias,
          value: p1, value2: p2);

  Condition<EntityT> oneOf(List<int> list, {String? alias}) =>
      _PropCondition<EntityT>(_model, _Op.oneOf, alias,
          list: List<Object?>.of(list));

  Condition<EntityT> notOneOf(List<int> list, {String? alias}) =>
      _PropCondition<EntityT>(_model, _Op.notOneOf, alias,
          list: List<Object?>.of(list));
}

class QueryDateProperty<EntityT> extends QueryIntegerProperty<EntityT> {
  QueryDateProperty(super.model);

  int _ms(DateTime value) => value.millisecondsSinceEpoch;

  Condition<EntityT> equalsDate(DateTime value, {String? alias}) =>
      equals(_ms(value), alias: alias);

  Condition<EntityT> notEqualsDate(DateTime value, {String? alias}) =>
      notEquals(_ms(value), alias: alias);

  Condition<EntityT> greaterThanDate(DateTime value, {String? alias}) =>
      greaterThan(_ms(value), alias: alias);

  Condition<EntityT> greaterOrEqualDate(DateTime value, {String? alias}) =>
      greaterOrEqual(_ms(value), alias: alias);

  Condition<EntityT> lessThanDate(DateTime value, {String? alias}) =>
      lessThan(_ms(value), alias: alias);

  Condition<EntityT> lessOrEqualDate(DateTime value, {String? alias}) =>
      lessOrEqual(_ms(value), alias: alias);

  Condition<EntityT> betweenDate(DateTime value1, DateTime value2,
          {String? alias}) =>
      between(_ms(value1), _ms(value2), alias: alias);

  Condition<EntityT> oneOfDate(List<DateTime> values, {String? alias}) =>
      oneOf(values.map(_ms).toList(), alias: alias);

  Condition<EntityT> notOneOfDate(List<DateTime> values, {String? alias}) =>
      notOneOf(values.map(_ms).toList(), alias: alias);
}

class QueryDateNanoProperty<EntityT> extends QueryIntegerProperty<EntityT> {
  QueryDateNanoProperty(super.model);

  int _ns(DateTime value) => value.microsecondsSinceEpoch * 1000;

  Condition<EntityT> equalsDate(DateTime value, {String? alias}) =>
      equals(_ns(value), alias: alias);

  Condition<EntityT> notEqualsDate(DateTime value, {String? alias}) =>
      notEquals(_ns(value), alias: alias);

  Condition<EntityT> greaterThanDate(DateTime value, {String? alias}) =>
      greaterThan(_ns(value), alias: alias);

  Condition<EntityT> greaterOrEqualDate(DateTime value, {String? alias}) =>
      greaterOrEqual(_ns(value), alias: alias);

  Condition<EntityT> lessThanDate(DateTime value, {String? alias}) =>
      lessThan(_ns(value), alias: alias);

  Condition<EntityT> lessOrEqualDate(DateTime value, {String? alias}) =>
      lessOrEqual(_ns(value), alias: alias);

  Condition<EntityT> betweenDate(DateTime value1, DateTime value2,
          {String? alias}) =>
      between(_ns(value1), _ns(value2), alias: alias);

  Condition<EntityT> oneOfDate(List<DateTime> values, {String? alias}) =>
      oneOf(values.map(_ns).toList(), alias: alias);

  Condition<EntityT> notOneOfDate(List<DateTime> values, {String? alias}) =>
      notOneOf(values.map(_ns).toList(), alias: alias);
}

class QueryIntegerVectorProperty<EntityT> extends QueryProperty<EntityT, int> {
  QueryIntegerVectorProperty(super.model);

  Condition<EntityT> _cond(_Op op, int p, String? alias) =>
      _PropCondition<EntityT>(_model, op, alias, value: p);

  Condition<EntityT> equals(int p, {String? alias}) => _cond(_Op.eq, p, alias);

  Condition<EntityT> greaterThan(int p, {String? alias}) =>
      _cond(_Op.gt, p, alias);

  Condition<EntityT> greaterOrEqual(int p, {String? alias}) =>
      _cond(_Op.goe, p, alias);

  Condition<EntityT> lessThan(int p, {String? alias}) =>
      _cond(_Op.lt, p, alias);

  Condition<EntityT> lessOrEqual(int p, {String? alias}) =>
      _cond(_Op.loe, p, alias);

  Condition<EntityT> operator <(int p) => lessThan(p);

  Condition<EntityT> operator >(int p) => greaterThan(p);
}

class QueryDoubleProperty<EntityT> extends QueryProperty<EntityT, double> {
  QueryDoubleProperty(super.model);

  Condition<EntityT> _cond(_Op op, double p, String? alias) =>
      _PropCondition<EntityT>(_model, op, alias, value: p);

  /// Finds objects with property value between and including the first and second value.
  Condition<EntityT> between(double p1, double p2, {String? alias}) =>
      _PropCondition<EntityT>(_model, _Op.between, alias,
          value: p1, value2: p2);

  Condition<EntityT> greaterThan(double p, {String? alias}) =>
      _cond(_Op.gt, p, alias);

  Condition<EntityT> greaterOrEqual(double p, {String? alias}) =>
      _cond(_Op.goe, p, alias);

  Condition<EntityT> lessThan(double p, {String? alias}) =>
      _cond(_Op.lt, p, alias);

  Condition<EntityT> lessOrEqual(double p, {String? alias}) =>
      _cond(_Op.loe, p, alias);

  Condition<EntityT> operator <(double p) => lessThan(p);

  Condition<EntityT> operator >(double p) => greaterThan(p);
}

class QueryDoubleVectorProperty<EntityT>
    extends QueryProperty<EntityT, double> {
  QueryDoubleVectorProperty(super.model);

  Condition<EntityT> _cond(_Op op, double p, String? alias) =>
      _PropCondition<EntityT>(_model, op, alias, value: p);

  Condition<EntityT> greaterThan(double p, {String? alias}) =>
      _cond(_Op.gt, p, alias);

  Condition<EntityT> greaterOrEqual(double p, {String? alias}) =>
      _cond(_Op.goe, p, alias);

  Condition<EntityT> lessThan(double p, {String? alias}) =>
      _cond(_Op.lt, p, alias);

  Condition<EntityT> lessOrEqual(double p, {String? alias}) =>
      _cond(_Op.loe, p, alias);

  Condition<EntityT> operator <(double p) => lessThan(p);

  Condition<EntityT> operator >(double p) => greaterThan(p);
}

class QueryHnswProperty<EntityT> extends QueryDoubleVectorProperty<EntityT> {
  QueryHnswProperty(super.model);

  Condition<EntityT> nearestNeighborsF32(
          List<double> queryVector, int maxResultCount, {String? alias}) =>
      _NearestNeighborsCondition<EntityT>(
          _model, List<double>.of(queryVector), maxResultCount, alias);
}

class QueryBooleanProperty<EntityT> extends QueryProperty<EntityT, bool> {
  QueryBooleanProperty(super.model);

  // ignore: avoid_positional_boolean_parameters
  Condition<EntityT> equals(bool p, {String? alias}) =>
      _PropCondition<EntityT>(_model, _Op.eq, alias, value: p);

  // ignore: avoid_positional_boolean_parameters
  Condition<EntityT> notEquals(bool p, {String? alias}) =>
      _PropCondition<EntityT>(_model, _Op.notEq, alias, value: p);
}

class QueryStringVectorProperty<EntityT>
    extends QueryProperty<EntityT, List<String>> {
  QueryStringVectorProperty(super.model);

  Condition<EntityT> containsElement(String value,
          {bool? caseSensitive, String? alias}) =>
      _PropCondition<EntityT>(_model, _Op.containsElement, alias,
          value: value, caseSensitive: caseSensitive);
}

class QueryRelationToOne<Source, Target> extends QueryIntegerProperty<Source> {
  QueryRelationToOne(super.model);
}

class QueryRelationToMany<Source, Target> {
  final ModelRelation _model;

  QueryRelationToMany(ModelRelation model) : _model = model;
}

class QueryBacklinkToMany<Source, Target> {
  final QueryRelationToOne<Source, Target> _relProp;

  QueryBacklinkToMany(QueryRelationToOne<Source, Target> relProp)
      : _relProp = relProp;

  Condition<Target> relationCount(int relationCount, {String? alias}) =>
      _RelationCountCondition<Target>(_relProp._model, relationCount, alias);
}

// ---------------------------------------------------------------- conditions

enum _Op {
  eq,
  notEq,
  contains,
  startsWith,
  endsWith,
  gt,
  goe,
  lt,
  loe,
  oneOf,
  notOneOf,
  between,
  isNull,
  notNull,
  containsElement,
}

class _EvalContext {
  final WebStoreEngine engine;
  final EntityData data;

  _EvalContext(this.engine, this.data);

  bool get caseSensitiveDefault =>
      engine.configuration.queriesCaseSensitiveDefault;

  _EvalContext withData(EntityData other) => _EvalContext(engine, other);
}

/// A [Query] condition base class.
abstract class Condition<EntityT> {
  final String? _alias;

  Condition(this._alias);

  // using & because && is not overridable
  Condition<EntityT> operator &(Condition<EntityT> rh) => and(rh);

  Condition<EntityT> and(Condition<EntityT> rh) => andAll([rh]);

  Condition<EntityT> andAll(List<Condition<EntityT>> rh) =>
      _ConditionGroupAll<EntityT>([this, ...rh]);

  // using | because || is not overridable
  Condition<EntityT> operator |(Condition<EntityT> rh) => or(rh);

  Condition<EntityT> or(Condition<EntityT> rh) => orAny([rh]);

  Condition<EntityT> orAny(List<Condition<EntityT>> rh) =>
      _ConditionGroupAny<EntityT>([this, ...rh]);

  bool _matches(_EvalContext ctx, int id, ByteData record);

  void _collect(
      List<_PropCondition> props, List<_NearestNeighborsCondition> nn) {}

  String _describe();
}

class _PropCondition<EntityT> extends Condition<EntityT> {
  final ModelProperty _property;
  final _Op _op;
  final bool? _caseSensitive;
  Object? _value;
  Object? _value2;
  List<Object?>? _list;

  _PropCondition(this._property, this._op, String? alias,
      {Object? value, Object? value2, List<Object?>? list, bool? caseSensitive})
      : _caseSensitive = caseSensitive,
        _value = value,
        _value2 = value2,
        _list = list,
        super(alias);

  @override
  void _collect(
          List<_PropCondition> props, List<_NearestNeighborsCondition> nn) =>
      props.add(this);

  @override
  bool _matches(_EvalContext ctx, int id, ByteData record) {
    final actual = readProperty(_property, record);
    switch (_op) {
      case _Op.isNull:
        return actual == null;
      case _Op.notNull:
        return actual != null;
      default:
        break;
    }
    if (actual == null) return false;

    final sensitive = _caseSensitive ?? ctx.caseSensitiveDefault;

    // String vector containsElement.
    if (_op == _Op.containsElement) {
      final elements = (actual as List).cast<String>();
      final needle =
          sensitive ? _value as String : (_value as String).toLowerCase();
      return elements.any((e) => (sensitive ? e : e.toLowerCase()) == needle);
    }

    // Scalar vectors (integer/double vector conditions): any element matches.
    if (actual is List && actual is! Uint8List && _value is num) {
      return actual.any((e) =>
          e is num && _compareNum(e, _value as num, _op, _value2 as num?));
    }

    if (actual is String) {
      var a = actual;
      var v = _value as String?;
      if (!sensitive) {
        a = a.toLowerCase();
        v = v?.toLowerCase();
      }
      switch (_op) {
        case _Op.eq:
          return a == v;
        case _Op.notEq:
          return a != v;
        case _Op.contains:
          return a.contains(v!);
        case _Op.startsWith:
          return a.startsWith(v!);
        case _Op.endsWith:
          return a.endsWith(v!);
        case _Op.gt:
          return a.compareTo(v!) > 0;
        case _Op.goe:
          return a.compareTo(v!) >= 0;
        case _Op.lt:
          return a.compareTo(v!) < 0;
        case _Op.loe:
          return a.compareTo(v!) <= 0;
        case _Op.oneOf:
          return _list!
              .map((e) => sensitive ? e as String : (e as String).toLowerCase())
              .contains(a);
        default:
          throw UnsupportedError('$_op on String');
      }
    }

    if (actual is bool) {
      switch (_op) {
        case _Op.eq:
          return actual == _value;
        case _Op.notEq:
          return actual != _value;
        default:
          throw UnsupportedError('$_op on bool');
      }
    }

    if (actual is Uint8List) {
      final cmp = _compareBytes(actual, (_value as List).cast<int>());
      switch (_op) {
        case _Op.eq:
          return cmp == 0;
        case _Op.gt:
          return cmp > 0;
        case _Op.goe:
          return cmp >= 0;
        case _Op.lt:
          return cmp < 0;
        case _Op.loe:
          return cmp <= 0;
        default:
          throw UnsupportedError('$_op on byte vector');
      }
    }

    if (actual is num) {
      switch (_op) {
        case _Op.oneOf:
          return _list!.contains(actual);
        case _Op.notOneOf:
          return !_list!.contains(actual);
        default:
          return _compareNum(actual, _value as num, _op, _value2 as num?);
      }
    }

    throw UnsupportedError('$_op on ${actual.runtimeType}');
  }

  static bool _compareNum(num a, num v, _Op op, num? v2) {
    switch (op) {
      case _Op.eq:
        return a == v;
      case _Op.notEq:
        return a != v;
      case _Op.gt:
        return a > v;
      case _Op.goe:
        return a >= v;
      case _Op.lt:
        return a < v;
      case _Op.loe:
        return a <= v;
      case _Op.between:
        return a >= v && a <= v2!;
      default:
        throw UnsupportedError('$op on num');
    }
  }

  static int _compareBytes(Uint8List a, List<int> b) {
    final len = math.min(a.length, b.length);
    for (var i = 0; i < len; i++) {
      final d = a[i].compareTo(b[i]);
      if (d != 0) return d;
    }
    return a.length.compareTo(b.length);
  }

  @override
  String _describe() => '${_property.name} $_op '
      '${_list ?? (_value2 == null ? _value : '[$_value, $_value2]')}'
      '${_alias == null ? '' : ' (alias: $_alias)'}';
}

class _NearestNeighborsCondition<EntityT> extends Condition<EntityT> {
  final ModelProperty _property;
  List<double> _queryVector;
  int _maxResultCount;

  _NearestNeighborsCondition(
      this._property, this._queryVector, this._maxResultCount, String? alias)
      : super(alias);

  @override
  void _collect(
          List<_PropCondition> props, List<_NearestNeighborsCondition> nn) =>
      nn.add(this);

  // The nearest-neighbor condition does not filter by itself; scoring and
  // result capping happen in Query. As a plain filter it matches objects
  // that have a vector at all.
  @override
  bool _matches(_EvalContext ctx, int id, ByteData record) =>
      readProperty(_property, record) != null;

  double? _score(ByteData record) {
    final value = readProperty(_property, record);
    if (value == null) return null;
    final vector = (value as List).cast<double>();
    final distanceType =
        _property.hnswParams?.distanceType ?? OBXVectorDistanceType.Euclidean;
    return _distance(vector, _queryVector, distanceType);
  }

  static double _distance(List<double> a, List<double> b, int type) {
    final len = math.min(a.length, b.length);
    switch (type) {
      case OBXVectorDistanceType.Cosine:
      case OBXVectorDistanceType.DotProduct:
      case OBXVectorDistanceType.DotProductNonNormalized:
        var dot = 0.0, normA = 0.0, normB = 0.0;
        for (var i = 0; i < len; i++) {
          dot += a[i] * b[i];
          normA += a[i] * a[i];
          normB += b[i] * b[i];
        }
        if (type == OBXVectorDistanceType.DotProduct) {
          // For normalized vectors the dot product equals cosine similarity.
          return 1.0 - dot;
        }
        if (type == OBXVectorDistanceType.DotProductNonNormalized) {
          final norm = math.sqrt(normA * normB);
          return norm == 0 ? 2.0 : 1.0 - dot / norm;
        }
        final norm = math.sqrt(normA) * math.sqrt(normB);
        return norm == 0 ? 2.0 : 1.0 - dot / norm;
      case OBXVectorDistanceType.Geo:
        throw UnsupportedError(
            'Geo vector distance is not supported on the web platform');
      case OBXVectorDistanceType.Euclidean:
      default:
        // Like the native default: Euclidean squared.
        var sum = 0.0;
        for (var i = 0; i < len; i++) {
          final d = a[i] - b[i];
          sum += d * d;
        }
        return sum;
    }
  }

  @override
  String _describe() =>
      '${_property.name} nearestNeighbors(dim: ${_queryVector.length}, '
      'max: $_maxResultCount)${_alias == null ? '' : ' (alias: $_alias)'}';
}

class _RelationCountCondition<EntityT> extends Condition<EntityT> {
  final ModelProperty _toOneProperty;
  final int _count;

  _RelationCountCondition(this._toOneProperty, this._count, String? alias)
      : super(alias);

  @override
  bool _matches(_EvalContext ctx, int id, ByteData record) {
    final sourceData = _entityOwning(ctx.engine, _toOneProperty);
    return ctx.engine
            .toOneBacklinkSources(sourceData, _toOneProperty.id.id, id)
            .length ==
        _count;
  }

  @override
  String _describe() => 'relationCount(${_toOneProperty.name}) == $_count';
}

class _ConditionGroup<EntityT> extends Condition<EntityT> {
  final List<Condition<EntityT>> _conditions;
  final bool _all;

  // ignore: avoid_positional_boolean_parameters
  _ConditionGroup(this._conditions, this._all) : super(null);

  @override
  bool _matches(_EvalContext ctx, int id, ByteData record) => _all
      ? _conditions.every((c) => c._matches(ctx, id, record))
      : _conditions.any((c) => c._matches(ctx, id, record));

  @override
  void _collect(
      List<_PropCondition> props, List<_NearestNeighborsCondition> nn) {
    for (final condition in _conditions) {
      condition._collect(props, nn);
    }
  }

  @override
  String _describe() =>
      '(${_conditions.map((c) => c._describe()).join(_all ? ' AND ' : ' OR ')})';
}

class _ConditionGroupAll<EntityT> extends _ConditionGroup<EntityT> {
  _ConditionGroupAll(List<Condition<EntityT>> conditions)
      : super(conditions, true);
}

class _ConditionGroupAny<EntityT> extends _ConditionGroup<EntityT> {
  _ConditionGroupAny(List<Condition<EntityT>> conditions)
      : super(conditions, false);
}

EntityData _entityOwning(WebStoreEngine engine, ModelProperty property) {
  for (final data in engine.entities.values) {
    if (data.model.properties.any((p) => identical(p, property))) return data;
  }
  throw ArgumentError('Property ${property.name} is not part of the model');
}

// ------------------------------------------------------------------- linking

class _LinkSpec {
  /// For ToOne links (forward or backlink): the relation property.
  final ModelProperty? property;

  /// For standalone ToMany links: the relation id.
  final int? relationId;

  /// True: source -> target (link/linkMany), false: backlink direction.
  final bool forward;

  /// The entity on the other side of the link.
  final EntityData otherData;

  final Condition? condition;
  final List<_LinkSpec> children = [];

  _LinkSpec(
      {this.property,
      this.relationId,
      required this.forward,
      required this.otherData,
      this.condition});

  bool _matches(_EvalContext ctx, int id, ByteData record) {
    final engine = ctx.engine;
    final List<int> otherIds;
    if (property != null) {
      if (forward) {
        final targetId = readIntProperty(property!, record);
        otherIds = targetId == 0 ? const [] : [targetId];
      } else {
        otherIds = engine.toOneBacklinkSources(otherData, property!.id.id, id);
      }
    } else {
      otherIds = forward
          ? engine.relTargets(relationId!, id)
          : engine.relBacklinkSources(relationId!, id);
    }
    final otherCtx = ctx.withData(otherData);
    for (final otherId in otherIds) {
      final otherBytes = otherData.records[otherId];
      if (otherBytes == null) continue;
      final otherRecord = ByteData.view(otherBytes.buffer,
          otherBytes.offsetInBytes, otherBytes.lengthInBytes);
      if (condition != null &&
          !condition!._matches(otherCtx, otherId, otherRecord)) {
        continue;
      }
      if (children
          .any((child) => !child._matches(otherCtx, otherId, otherRecord))) {
        continue;
      }
      return true;
    }
    return false;
  }
}

class _OrderSpec {
  final ModelProperty property;
  final int flags;

  _OrderSpec(this.property, this.flags);
}

// -------------------------------------------------------------------- query

/// A repeatable Query returning the latest matching Objects.
class Query<T> {
  final Store _store;
  final WebStoreEngine _engine;
  final EntityData _data;
  final EntityDefinition<T> _entity;
  final Condition<T>? _condition;
  final List<_OrderSpec> _orders;
  final List<_LinkSpec> _links;
  int _offset = 0;
  int _limit = 0;

  Query._(this._store, this._engine, this._data, this._entity, this._condition,
      this._orders, this._links);

  int get entityId => _data.model.id.id;

  set offset(int offset) => _offset = offset;

  set limit(int limit) => _limit = limit;

  _EvalContext get _ctx => _EvalContext(_engine, _data);

  _NearestNeighborsCondition? get _nnCondition {
    final props = <_PropCondition>[];
    final nn = <_NearestNeighborsCondition>[];
    _condition?._collect(props, nn);
    if (nn.length > 1) {
      throw UnsupportedError(
          'Only a single nearestNeighbors condition is supported per query');
    }
    return nn.isEmpty ? null : nn.first;
  }

  /// Ids of all matching objects with conditions, links, nearest-neighbor
  /// scoring, ordering, offset and limit applied. [scores] is filled when a
  /// nearest-neighbor condition is present (then results are score-ordered).
  List<int> _matchingIds({Map<int, double>? scores}) {
    _engine.checkOpen();
    final ctx = _ctx;
    final nn = _nnCondition;
    var candidates = <int>[];
    _data.records.forEach((id, bytes) {
      final record =
          ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);
      if (_condition != null && !_condition._matches(ctx, id, record)) {
        return;
      }
      if (_links.any((link) => !link._matches(ctx, id, record))) return;
      candidates.add(id);
    });

    if (nn != null) {
      final withScores = <(int, double)>[];
      for (final id in candidates) {
        final bytes = _data.records[id]!;
        final score = nn._score(ByteData.view(
            bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes));
        if (score != null) withScores.add((id, score));
      }
      withScores.sort((a, b) => a.$2.compareTo(b.$2));
      final capped = withScores.take(nn._maxResultCount).toList();
      if (scores != null) {
        for (final (id, score) in capped) {
          scores[id] = score;
        }
      }
      candidates = [for (final (id, _) in capped) id];
    } else if (_orders.isNotEmpty) {
      candidates.sort(_comparator());
    }

    if (_offset > 0) {
      candidates =
          candidates.length > _offset ? candidates.sublist(_offset) : <int>[];
    }
    if (_limit > 0 && candidates.length > _limit) {
      candidates = candidates.sublist(0, _limit);
    }
    return candidates;
  }

  Comparator<int> _comparator() => (int a, int b) {
        for (final order in _orders) {
          final va = _readOrderValue(order, a);
          final vb = _readOrderValue(order, b);
          var result = _compareValues(va, vb, order.flags);
          if ((order.flags & 1) != 0) result = -result; // Order.descending
          if (result != 0) return result;
        }
        return a.compareTo(b);
      };

  Object? _readOrderValue(_OrderSpec order, int id) {
    final bytes = _data.records[id]!;
    var value = readProperty(order.property,
        ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes));
    if (value == null && (order.flags & 16) != 0) value = 0; // nullsAsZero
    return value;
  }

  static int _compareValues(Object? a, Object? b, int flags) {
    if (a == null && b == null) return 0;
    // Nulls first by default, last with Order.nullsLast. (Applied before the
    // descending inversion, like the native implementation.)
    final nullsLast = (flags & 8) != 0;
    if (a == null) return nullsLast ? 1 : -1;
    if (b == null) return nullsLast ? -1 : 1;
    if (a is String && b is String) {
      // Case-insensitive unless Order.caseSensitive.
      if ((flags & 2) == 0) {
        final result = a.toLowerCase().compareTo(b.toLowerCase());
        if (result != 0) return result;
      }
      return a.compareTo(b);
    }
    if (a is bool && b is bool) return (a ? 1 : 0).compareTo(b ? 1 : 0);
    if (a is num && b is num) {
      if ((flags & 4) != 0) {
        // Order.unsigned: negative values sort after positive ones.
        final ua = a < 0 ? a + 18446744073709551616.0 : a;
        final ub = b < 0 ? b + 18446744073709551616.0 : b;
        return ua.compareTo(ub);
      }
      return a.compareTo(b);
    }
    return 0;
  }

  int count() => _matchingIds().length;

  int remove() {
    final ids = _matchingIds();
    return _engine.runInTx(() {
      var removed = 0;
      for (final id in ids) {
        if (_engine.removeRecord(_data, id)) removed++;
      }
      return removed;
    });
  }

  Future<int> removeAsync() => Future.microtask(remove);

  void close() {
    // Nothing to release on web.
  }

  T _objectFromBytes(Uint8List bytes) => _entity.objectFromFB(
      // ignore: argument_type_not_assignable
      _store,
      ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes));

  T? _get(int id) {
    final bytes = _data.records[id];
    return bytes == null ? null : _objectFromBytes(bytes);
  }

  T? findFirst() {
    final ids = _matchingIds();
    return ids.isEmpty ? null : _get(ids.first);
  }

  Future<T?> findFirstAsync() => Future.microtask(findFirst);

  T? findUnique() {
    final ids = _matchingIds();
    if (ids.length > 1) {
      throw NonUniqueResultException(
          'Query findUnique() matched more than one object');
    }
    return ids.isEmpty ? null : _get(ids.first);
  }

  Future<T?> findUniqueAsync() => Future.microtask(findUnique);

  List<int> findIds() => _matchingIds();

  Future<List<int>> findIdsAsync() => Future.microtask(findIds);

  List<T> find() => _matchingIds().map(_get).whereType<T>().toList();

  Future<List<T>> findAsync() => Future.microtask(find);

  Map<int, double> _requireScores() {
    if (_nnCondition == null) {
      throw StateError(
          'This query does not use a nearestNeighborsF32 condition, '
          'so there are no scores');
    }
    return <int, double>{};
  }

  List<IdWithScore> findIdsWithScores() {
    final scores = _requireScores();
    final ids = _matchingIds(scores: scores);
    return [for (final id in ids) IdWithScore(id, scores[id]!)];
  }

  Future<List<IdWithScore>> findIdsWithScoresAsync() =>
      Future.microtask(findIdsWithScores);

  List<ObjectWithScore<T>> findWithScores() {
    final scores = _requireScores();
    final ids = _matchingIds(scores: scores);
    return [
      for (final id in ids)
        if (_get(id) case final T object)
          ObjectWithScore<T>(object, scores[id]!)
    ];
  }

  Future<List<ObjectWithScore<T>>> findWithScoresAsync() =>
      Future.microtask(findWithScores);

  Stream<T> stream() => Stream.fromIterable(find());

  /// For internal testing purposes.
  String describe() => 'Query for entity ${_data.model.name} with condition: '
      '${_condition?._describe() ?? '(none)'}'
      '${_links.isEmpty ? '' : ' with ${_links.length} link(s)'}';

  /// For internal testing purposes.
  String describeParameters() {
    final props = <_PropCondition>[];
    final nn = <_NearestNeighborsCondition>[];
    _condition?._collect(props, nn);
    return [...props, ...nn].map((c) => c._describe()).join('\n');
  }

  PropertyQuery<DartType> property<DartType>(QueryProperty<T, DartType> prop) =>
      PropertyQuery<DartType>._(
          this, prop._model, _engine.configuration.queriesCaseSensitiveDefault);
}

// ------------------------------------------------------------------ builder

/// Query builder allows creating reusable queries.
class QueryBuilder<T> {
  final Store? _store;
  final EntityDefinition<T>? _entity;
  final WebStoreEngine _engine;
  final Condition<T>? _condition;
  final List<_OrderSpec> _orders = [];
  final List<_LinkSpec> _links = [];

  /// When this is a sub-builder created by link/backlink, conditions and
  /// nested links are attached to this spec; build() is only available on
  /// the root builder.
  final _LinkSpec? _linkSpec;

  factory QueryBuilder(
          Store store, EntityDefinition<T> entity, Condition<T>? qc) =>
      QueryBuilder._(store, entity, InternalStoreAccess.engine(store), qc);

  QueryBuilder._(this._store, this._entity, this._engine, this._condition)
      : _linkSpec = null;

  QueryBuilder._sub(this._engine, this._linkSpec)
      : _store = null,
        _entity = null,
        _condition = null;

  EntityData get _data => _linkSpec != null
      ? _linkSpec.otherData
      : _engine.entities[_entity!.model.id.id]!;

  Query<T> build() {
    if (_linkSpec != null) {
      throw StateError(
          'build() is only available on the root query builder, not on a '
          'linked builder');
    }
    return Query<T>._(_store!, _engine, _data, _entity!, _condition,
        List.of(_orders), List.of(_links));
  }

  Stream<Query<T>> watch({bool triggerImmediately = false}) {
    final query = build();
    final entityType = _entity!.type();
    final source = _engine.changes.stream
        .where((types) => types.contains(entityType))
        .map((_) => query);
    if (!triggerImmediately) return source;
    late StreamController<Query<T>> controller;
    StreamSubscription<Query<T>>? subscription;
    controller = StreamController<Query<T>>(
        onListen: () {
          controller.add(query);
          subscription = source.listen(controller.add,
              onError: controller.addError, onDone: controller.close);
        },
        onCancel: () => subscription?.cancel());
    return controller.stream;
  }

  QueryBuilder<T> order<D>(QueryProperty<T, D> p, {int flags = 0}) {
    if (_linkSpec != null) {
      throw StateError('order() is only available on the root query builder');
    }
    _orders.add(_OrderSpec(p._model, flags));
    // Fluent API matching the native implementation.
    // ignore: avoid_returning_this
    return this;
  }

  _LinkSpec _addLink(_LinkSpec spec) {
    if (_linkSpec != null) {
      _linkSpec.children.add(spec);
    } else {
      _links.add(spec);
    }
    return spec;
  }

  EntityData _dataOf(Type type) {
    final data = _engine.entitiesByType[type];
    if (data == null) {
      throw ArgumentError('Unknown entity type $type in link');
    }
    return data;
  }

  // Note: in the native implementation the following link methods live on a
  // private base class `_QueryBuilder` which is also their return type. As a
  // private type cannot be mirrored here, the methods are flattened into this
  // class and return [QueryBuilder]; the returned (sub-)builder supports the
  // same chained link calls, but not build()/watch()/order().

  QueryBuilder<TargetEntityT> link<TargetEntityT>(
          QueryRelationToOne<T, TargetEntityT> rel,
          [Condition<TargetEntityT>? qc]) =>
      QueryBuilder<TargetEntityT>._sub(
          _engine,
          _addLink(_LinkSpec(
              property: rel._model,
              forward: true,
              otherData: _dataOf(TargetEntityT),
              condition: qc)));

  QueryBuilder<SourceEntityT> backlink<SourceEntityT>(
          QueryRelationToOne<SourceEntityT, T> rel,
          [Condition<SourceEntityT>? qc]) =>
      QueryBuilder<SourceEntityT>._sub(
          _engine,
          _addLink(_LinkSpec(
              property: rel._model,
              forward: false,
              otherData: _dataOf(SourceEntityT),
              condition: qc)));

  QueryBuilder<TargetEntityT> linkMany<TargetEntityT>(
          QueryRelationToMany<T, TargetEntityT> rel,
          [Condition<TargetEntityT>? qc]) =>
      QueryBuilder<TargetEntityT>._sub(
          _engine,
          _addLink(_LinkSpec(
              relationId: rel._model.id.id,
              forward: true,
              otherData: _dataOf(TargetEntityT),
              condition: qc)));

  QueryBuilder<SourceEntityT> backlinkMany<SourceEntityT>(
          QueryRelationToMany<SourceEntityT, T> rel,
          [Condition<SourceEntityT>? qc]) =>
      QueryBuilder<SourceEntityT>._sub(
          _engine,
          _addLink(_LinkSpec(
              relationId: rel._model.id.id,
              forward: false,
              otherData: _dataOf(SourceEntityT),
              condition: qc)));
}

// ------------------------------------------------------------------- params

/// Adds capabilities to set query parameters
extension QuerySetParam on Query {
  QueryParam<DartType> param<EntityT, DartType>(
      QueryProperty<EntityT, DartType> prop,
      {String? alias}) {
    final props = <_PropCondition>[];
    final nn = <_NearestNeighborsCondition>[];
    _condition?._collect(props, nn);
    for (final link in _links) {
      link.condition?._collect(props, nn);
    }
    final matchingProps = props
        .where((c) =>
            identical(c._property, prop._model) &&
            (alias == null || c._alias == alias))
        .toList();
    final matchingNn = nn
        .where((c) =>
            identical(c._property, prop._model) &&
            (alias == null || c._alias == alias))
        .toList();
    if (matchingProps.isEmpty && matchingNn.isEmpty) {
      throw ArgumentError(
          'No query condition found for property "${prop._model.name}"'
          '${alias == null ? '' : ' with alias "$alias"'}');
    }
    return QueryParam<DartType>._(matchingProps, matchingNn);
  }
}

/// QueryParam
class QueryParam<DartType> {
  final List<_PropCondition> _conditions;
  final List<_NearestNeighborsCondition> _nnConditions;

  QueryParam._(this._conditions, this._nnConditions);

  void _setValue(Object? value) {
    for (final condition in _conditions) {
      condition._value = value;
    }
  }

  void _setValues(List<Object?> values) {
    for (final condition in _conditions) {
      condition._list = values;
    }
  }

  void _setTwoValues(Object? a, Object? b) {
    for (final condition in _conditions) {
      condition._value = a;
      condition._value2 = b;
    }
  }
}

/// QueryParam for string properties
extension QueryParamString on QueryParam<String> {
  set value(String value) => _setValue(value);

  set values(List<String> values) => _setValues(List<Object?>.of(values));
}

/// QueryParam for byte vector properties
extension QueryParamBytes on QueryParam<List<int>> {
  set value(List<int> value) => _setValue(value);
}

/// QueryParam for int properties
extension QueryParamInt on QueryParam<int> {
  set value(int value) => _setValue(value);

  set values(List<int> values) => _setValues(List<Object?>.of(values));

  /// set values for condition consisting of two values
  void twoValues(int a, int b) => _setTwoValues(a, b);
}

/// QueryParam for double properties
extension QueryParamDouble on QueryParam<double> {
  set value(double value) => _setValue(value);

  /// set values for condition consisting of two values
  void twoValues(double a, double b) => _setTwoValues(a, b);

  /// Set values for the nearest neighbor condition.
  void nearestNeighborsF32(List<double> queryVector, int maxResultCount) {
    if (_nnConditions.isEmpty) {
      throw ArgumentError('No nearestNeighborsF32 condition in this query');
    }
    for (final condition in _nnConditions) {
      condition._queryVector = List<double>.of(queryVector);
      condition._maxResultCount = maxResultCount;
    }
  }
}

/// QueryParam for boolean properties
extension QueryParamBool on QueryParam<bool> {
  set value(bool value) => _setValue(value);
}

// ----------------------------------------------------------- property query

/// Property query base.
class PropertyQuery<T> {
  final Query _query;
  final ModelProperty _property;
  bool _distinct = false;
  bool _caseSensitive;

  PropertyQuery._(this._query, this._property, this._caseSensitive);

  /// Close the property query, freeing its resources
  void close() {}

  /// Property values of all objects matching the query conditions (offset and
  /// limit are not applied, like in the native implementation). Nulls are
  /// excluded unless [replaceNullWith] is provided.
  List<Object?> _values({Object? replaceNullWith}) {
    // Property queries ignore offset/limit; run over all condition matches.
    final query = _query;
    final saveOffset = query._offset, saveLimit = query._limit;
    query._offset = 0;
    query._limit = 0;
    final List<int> ids;
    try {
      ids = query._matchingIds();
    } finally {
      query._offset = saveOffset;
      query._limit = saveLimit;
    }
    final result = <Object?>[];
    for (final id in ids) {
      final bytes = query._data.records[id]!;
      final value = readProperty(
          _property,
          ByteData.view(
              bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes));
      if (value == null) {
        if (replaceNullWith != null) result.add(replaceNullWith);
        continue;
      }
      result.add(value);
    }
    if (_distinct) {
      final seen = <Object?>{};
      result.retainWhere((v) =>
          seen.add(v is String && !_caseSensitive ? v.toLowerCase() : v));
    }
    return result;
  }

  List<num> _numValues() => _values().cast<num>();
}

/// "Property query" for an integer field. Created by [Query.property()].
extension IntegerPropertyQuery on PropertyQuery<int> {
  double average() {
    final values = _numValues();
    return values.isEmpty
        ? 0
        : values.fold<num>(0, (a, b) => a + b) / values.length;
  }

  int count() => _values().length;

  bool get distinct => _distinct;

  set distinct(bool d) => _distinct = d;

  int min() =>
      _numValues()
          .fold<int?>(null, (m, v) => m == null || v < m ? v as int : m) ??
      0;

  int max() =>
      _numValues()
          .fold<int?>(null, (m, v) => m == null || v > m ? v as int : m) ??
      0;

  int sum() => _numValues().fold<int>(0, (a, b) => a + (b as int));

  List<int> find({int? replaceNullWith}) =>
      _values(replaceNullWith: replaceNullWith).cast<int>();
}

/// "Property query" for a double field. Created by [Query.property()].
extension DoublePropertyQuery on PropertyQuery<double> {
  double average() {
    final values = _numValues();
    return values.isEmpty
        ? 0
        : values.fold<num>(0, (a, b) => a + b) / values.length;
  }

  int count() => _values().length;

  bool get distinct => _distinct;

  set distinct(bool d) => _distinct = d;

  double min() =>
      _numValues().fold<double?>(
          null, (m, v) => m == null || v < m ? v.toDouble() : m) ??
      0;

  double max() =>
      _numValues().fold<double?>(
          null, (m, v) => m == null || v > m ? v.toDouble() : m) ??
      0;

  double sum() => _numValues().fold<double>(0, (a, b) => a + b);

  List<double> find({double? replaceNullWith}) =>
      _values(replaceNullWith: replaceNullWith).cast<double>();
}

/// "Property query" for a string field. Created by [Query.property()].
extension StringPropertyQuery on PropertyQuery<String> {
  /// Use case-sensitive comparison when querying [distinct] values.
  set caseSensitive(bool caseSensitive) => _caseSensitive = caseSensitive;

  /// Get status of the case-sensitive configuration.
  bool get caseSensitive => _caseSensitive;

  bool get distinct => _distinct;

  set distinct(bool d) => _distinct = d;

  int count() => _values().length;

  List<String> find({String? replaceNullWith}) =>
      _values(replaceNullWith: replaceNullWith).cast<String>();
}
