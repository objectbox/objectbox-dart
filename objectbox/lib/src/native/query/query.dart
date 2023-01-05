library query;

import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../../common.dart';
import '../../modelinfo/entity_definition.dart';
import '../../modelinfo/modelproperty.dart';
import '../../modelinfo/modelrelation.dart';
import '../../store.dart';
import '../../transaction.dart';
import '../bindings/bindings.dart';
import '../bindings/data_visitor.dart';
import '../bindings/helpers.dart';

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
  /// signed, unless the property is annotated with [@Property(signed: false)].
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
  QueryStringProperty(ModelProperty model) : super(model);

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
  QueryByteVectorProperty(ModelProperty model) : super(model);

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
  QueryIntegerProperty(ModelProperty model) : super(model);

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

  Condition<EntityT> between(int p1, int p2, {String? alias}) =>
      _op(_ConditionOp.between, p1, p2, alias);

  Condition<EntityT> oneOf(List<int> list, {String? alias}) =>
      _opList(list, _ConditionOp.oneOf, alias);

  Condition<EntityT> notOneOf(List<int> list, {String? alias}) =>
      _opList(list, _ConditionOp.notOneOf, alias);
}

class QueryDoubleProperty<EntityT> extends QueryProperty<EntityT, double> {
  QueryDoubleProperty(ModelProperty model) : super(model);

  Condition<EntityT> _op(
          _ConditionOp op, double p1, double? p2, String? alias) =>
      _DoubleCondition<EntityT>(op, this, p1, p2, alias);

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

class QueryBooleanProperty<EntityT> extends QueryProperty<EntityT, bool> {
  QueryBooleanProperty(ModelProperty model) : super(model);

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
  QueryStringVectorProperty(ModelProperty model) : super(model);

  @Deprecated(
      'Use `containsElement` instead. Will be removed in a future release.')
  Condition<EntityT> contains(String p, {bool? caseSensitive, String? alias}) =>
      containsElement(p, caseSensitive: caseSensitive, alias: alias);

  /// Matches if at least one element of the list equals the given value.
  Condition<EntityT> containsElement(String value,
          {bool? caseSensitive, String? alias}) =>
      _StringCondition<EntityT, List<String>>(
          _ConditionOp.containsElement, this, value, null, alias,
          caseSensitive: caseSensitive);
}

class QueryRelationToOne<Source, Target> extends QueryIntegerProperty<Source> {
  QueryRelationToOne(ModelProperty model) : super(model);
}

class QueryRelationToMany<Source, Target> {
  final ModelRelation _model;

  QueryRelationToMany(this._model);
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
          (Pointer<Int8> cStr) => C.qb_param_alias(builder._cBuilder, cStr)));
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

  _StringCondition(
      _ConditionOp op,
      QueryProperty<EntityT, PropertyDartType> prop,
      String value,
      String? value2,
      String? alias,
      {this.caseSensitive})
      : super(op, prop, value, value2, alias);

  int _op1(_QueryBuilder builder,
      int Function(Pointer<OBX_query_builder>, int, Pointer<Int8>, bool) func) {
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
      (Pointer<Pointer<Int8>> ptr, int size) => C.qb_in_strings(
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
      _ConditionOp op,
      QueryProperty<EntityT, PropertyDartType> prop,
      int value,
      int? value2,
      String? alias)
      : super(op, prop, value, value2, alias);

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
  final int Function(Pointer<OBX_query_builder>, Pointer<Int32>, int) _func;

  _ConditionGroup(this._conditions, this._func) : super(null);

  @override
  int _apply(_QueryBuilder builder, {required bool isRoot}) {
    final size = _conditions.length;

    if (size == 0) {
      return -1; // -1 instead of 0 which indicates an error
    } else if (size == 1) {
      return _conditions[0]._applyFull(builder, isRoot: isRoot);
    }

    final intArrayPtr = malloc<Int32>(size);
    try {
      for (var i = 0; i < size; ++i) {
        final cid = _conditions[i]._applyFull(builder, isRoot: false);
        if (cid == 0) {
          builder._throwExceptionIfNecessary();
          throw StateError(
              'Failed to create condition ' + _conditions[i].toString());
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
class Query<T> {
  bool _closed = false;
  final Pointer<OBX_query> _cQuery;
  late final Pointer<OBX_dart_finalizer> _cFinalizer;
  final Store _store;
  final EntityDefinition<T> _entity;

  int get entityId => _entity.model.id.id;

  Pointer<OBX_query> get _ptr {
    if (_closed) {
      throw StateError('Query already closed, cannot execute any actions');
    }
    return _cQuery;
  }

  Query._(this._store, Pointer<OBX_query_builder> cBuilder, this._entity)
      : _cQuery = checkObxPtr(C.query(cBuilder), 'create query') {
    initializeDartAPI();

    // Keep the finalizer so we can detach it when close() is called manually.
    _cFinalizer =
        C.dartc_attach_finalizer(this, native_query_close, _cQuery.cast(), 256);
    if (_cFinalizer == nullptr) {
      close();
      throwLatestNativeError();
    }
  }

  /// Configure an [offset] for this query.
  ///
  /// All methods that support offset will return/process Objects starting at
  /// this offset. Example use case: use together with limit to get a slice of
  /// the whole result, e.g. for "result paging".
  ///
  /// Set offset=0 to reset to the default - starting from the first element.
  set offset(int offset) {
    final result = checkObx(C.query_offset(_ptr, offset));
    reachabilityFence(this);
    return result;
  }

  /// Configure a [limit] for this query.
  ///
  /// All methods that support limit will return/process only the given number
  /// of Objects. Example use case: use together with offset to get a slice of
  /// the whole result, e.g. for "result paging".
  ///
  /// Set limit=0 to reset to the default behavior - no limit applied.
  set limit(int limit) {
    final result = checkObx(C.query_limit(_ptr, limit));
    reachabilityFence(this);
    return result;
  }

  /// Returns the number of matching Objects.
  int count() {
    final ptr = malloc<Uint64>();
    try {
      checkObx(C.query_count(_ptr, ptr));
      reachabilityFence(this);
      return ptr.value;
    } finally {
      malloc.free(ptr);
    }
  }

  /// Returns the number of removed Objects.
  int remove() {
    final ptr = malloc<Uint64>();
    try {
      checkObx(C.query_remove(_ptr, ptr));
      return ptr.value;
    } finally {
      malloc.free(ptr);
    }
  }

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
  Pointer<OBX_query> _clone() {
    final ptr = checkObxPtr(C.query_clone(_ptr));
    reachabilityFence(this);
    return ptr;
  }

  /// Close the query and free resources.
  void close() {
    if (!_closed) {
      _closed = true;
      var err = 0;
      if (_cFinalizer != nullptr) {
        err = C.dartc_detach_finalizer(_cFinalizer, this);
      }
      checkObx(C.query_close(_cQuery));
      checkObx(err);
    }
  }

  /// Finds the first object matching the query. Returns null if there are no
  /// results. Note: [offset] and [limit] are respected, if set.
  T? findFirst() {
    T? result;
    Object? error;
    final visitor = dataVisitor((Pointer<Uint8> data, int size) {
      try {
        result = _entity.objectFromFB(
            _store, InternalStoreAccess.reader(_store).access(data, size));
      } catch (e) {
        error = e;
      }
      return false; // we only want to visit the first element
    });
    checkObx(C.query_visit(_ptr, visitor, nullptr));
    if (error != null) throw error!;
    reachabilityFence(this);
    return result;
  }

  /// Finds the only object matching the query. Returns null if there are no
  /// results or throws [NonUniqueResultException] if there are multiple objects
  /// matching.
  ///
  /// Note: [offset] and [limit] are respected, if set. Because [limit] affects
  /// the number of matched objects, make sure you leave it at zero or set it
  /// higher than one, otherwise the check for non-unique result won't work.
  T? findUnique() {
    T? result;
    Object? error;
    final visitor = dataVisitor((Pointer<Uint8> data, int size) {
      if (result == null) {
        try {
          result = _entity.objectFromFB(
              _store, InternalStoreAccess.reader(_store).access(data, size));
          return true;
        } catch (e) {
          error = e;
          return false;
        }
      } else {
        error = NonUniqueResultException(
            'Query findUnique() matched more than one object');
        return false;
      }
    });
    checkObx(C.query_visit(_ptr, visitor, nullptr));
    reachabilityFence(this);
    if (error != null) throw error!;
    return result;
  }

  /// Finds Objects matching the query and returns their IDs.
  List<int> findIds() {
    final idArrayPtr = checkObxPtr(C.query_find_ids(_ptr), 'find ids');
    reachabilityFence(this);
    try {
      final idArray = idArrayPtr.ref;
      final ids = idArray.ids;
      return List.generate(idArray.count, (i) => ids[i], growable: false);
    } finally {
      C.id_array_free(idArrayPtr);
    }
  }

  /// Finds Objects matching the query.
  List<T> find() {
    final result = <T>[];
    final errorWrapper = ObjectCollectorError();
    final collector = objectCollector(result, _store, _entity, errorWrapper);
    checkObx(C.query_visit(_ptr, collector, nullptr));
    errorWrapper.throwIfError();
    reachabilityFence(this);
    return result;
  }

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
  //     reachabilityFence(this);
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
            streamController.add(_entity.objectFromFB(
                _store,
                InternalStoreAccess.reader(_store)
                    .access(Pointer.fromAddress(dataPtrAddress), size)));
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
        final visitor = dataVisitor((Pointer<Uint8> data, int size) {
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
        });
        final queryPtr =
            Pointer<OBX_query>.fromAddress(isolateInit.queryPtrAddress);
        try {
          checkObx(C.query_visit(queryPtr, visitor, nullptr));
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
  String describe() {
    final result = dartStringFromC(C.query_describe(_ptr));
    reachabilityFence(this);
    return result;
  }

  /// For internal testing purposes.
  String describeParameters() {
    final result = dartStringFromC(C.query_describe_params(_ptr));
    reachabilityFence(this);
    return result;
  }

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
        C.query_prop(_ptr, prop._model.id.id), prop._model.type);
    reachabilityFence(this);
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
