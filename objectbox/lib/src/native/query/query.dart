library query;

import 'dart:async';
import 'dart:collection';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

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

  Condition<EntityT> isNull() =>
      _NullCondition<EntityT, DartType>(_ConditionOp.isNull, this);

  Condition<EntityT> notNull() =>
      _NullCondition<EntityT, DartType>(_ConditionOp.notNull, this);
}

class QueryStringProperty<EntityT> extends QueryProperty<EntityT, String> {
  QueryStringProperty(ModelProperty model) : super(model);

  Condition<EntityT> _op(String p, _ConditionOp cop, {bool? caseSensitive}) =>
      _StringCondition<EntityT, String>(cop, this, p, null,
          caseSensitive: caseSensitive);

  Condition<EntityT> _opList(List<String> list, _ConditionOp cop,
          {bool? caseSensitive}) =>
      _StringListCondition<EntityT>(cop, this, list,
          caseSensitive: caseSensitive);

  Condition<EntityT> equals(String p, {bool? caseSensitive}) =>
      _op(p, _ConditionOp.eq, caseSensitive: caseSensitive);

  Condition<EntityT> notEquals(String p, {bool? caseSensitive}) =>
      _op(p, _ConditionOp.notEq, caseSensitive: caseSensitive);

  Condition<EntityT> endsWith(String p, {bool? caseSensitive}) =>
      _op(p, _ConditionOp.endsWith, caseSensitive: caseSensitive);

  Condition<EntityT> startsWith(String p, {bool? caseSensitive}) =>
      _op(p, _ConditionOp.startsWith, caseSensitive: caseSensitive);

  Condition<EntityT> contains(String p, {bool? caseSensitive}) =>
      _op(p, _ConditionOp.contains, caseSensitive: caseSensitive);

  Condition<EntityT> oneOf(List<String> list, {bool? caseSensitive}) =>
      _opList(list, _ConditionOp.oneOf, caseSensitive: caseSensitive);

  Condition<EntityT> notOneOf(List<String> list, {bool? caseSensitive}) =>
      _opList(list, _ConditionOp.notOneOf, caseSensitive: caseSensitive);

  Condition<EntityT> greaterThan(String p, {bool? caseSensitive}) =>
      _op(p, _ConditionOp.gt, caseSensitive: caseSensitive);

  Condition<EntityT> greaterOrEqual(String p, {bool? caseSensitive}) =>
      _op(p, _ConditionOp.greaterOrEq, caseSensitive: caseSensitive);

  Condition<EntityT> lessThan(String p, {bool? caseSensitive}) =>
      _op(p, _ConditionOp.lt, caseSensitive: caseSensitive);

  Condition<EntityT> lessOrEqual(String p, {bool? caseSensitive}) =>
      _op(p, _ConditionOp.lessOrEq, caseSensitive: caseSensitive);
}

class QueryByteVectorProperty<EntityT>
    extends QueryProperty<EntityT, Uint8List> {
  QueryByteVectorProperty(ModelProperty model) : super(model);

  Condition<EntityT> _op(List<int> val, _ConditionOp cop) =>
      _ByteVectorCondition<EntityT>(cop, this, Uint8List.fromList(val));

  Condition<EntityT> equals(List<int> val) => _op(val, _ConditionOp.eq);

  Condition<EntityT> greaterThan(List<int> val) => _op(val, _ConditionOp.gt);

  Condition<EntityT> greaterOrEqual(List<int> val) =>
      _op(val, _ConditionOp.greaterOrEq);

  Condition<EntityT> lessThan(List<int> val) => _op(val, _ConditionOp.lt);

  Condition<EntityT> lessOrEqual(List<int> val) =>
      _op(val, _ConditionOp.lessOrEq);
}

class QueryIntegerProperty<EntityT> extends QueryProperty<EntityT, int> {
  QueryIntegerProperty(ModelProperty model) : super(model);

  Condition<EntityT> _op(int p, _ConditionOp cop) =>
      _IntegerCondition<EntityT, int>(cop, this, p, 0);

  Condition<EntityT> _opList(List<int> list, _ConditionOp cop) =>
      _IntegerListCondition<EntityT>(cop, this, list);

  Condition<EntityT> equals(int p) => _op(p, _ConditionOp.eq);

  Condition<EntityT> notEquals(int p) => _op(p, _ConditionOp.notEq);

  Condition<EntityT> greaterThan(int p) => _op(p, _ConditionOp.gt);

  Condition<EntityT> greaterOrEqual(int p) => _op(p, _ConditionOp.greaterOrEq);

  Condition<EntityT> lessThan(int p) => _op(p, _ConditionOp.lt);

  Condition<EntityT> lessOrEqual(int p) => _op(p, _ConditionOp.lessOrEq);

  Condition<EntityT> operator <(int p) => lessThan(p);

  Condition<EntityT> operator >(int p) => greaterThan(p);

  Condition<EntityT> oneOf(List<int> list) => _opList(list, _ConditionOp.oneOf);

  Condition<EntityT> notOneOf(List<int> list) =>
      _opList(list, _ConditionOp.notOneOf);
}

class QueryDoubleProperty<EntityT> extends QueryProperty<EntityT, double> {
  QueryDoubleProperty(ModelProperty model) : super(model);

  Condition<EntityT> _op(_ConditionOp op, double p1, double? p2) =>
      _DoubleCondition<EntityT>(op, this, p1, p2);

  Condition<EntityT> between(double p1, double p2) =>
      _op(_ConditionOp.between, p1, p2);

  // NOTE: objectbox-c doesn't support double/float equality (because it's a
  // rather peculiar thing). Therefore, we're currently not providing this in
  // Dart either, not even with some `between()` workarounds.
  // Condition<EntityT> equals(double p) {
  //    _op(_ConditionOp.eq, p);
  // }

  Condition<EntityT> greaterThan(double p) => _op(_ConditionOp.gt, p, null);

  Condition<EntityT> greaterOrEqual(double p) =>
      _op(_ConditionOp.greaterOrEq, p, null);

  Condition<EntityT> lessThan(double p) => _op(_ConditionOp.lt, p, null);

  Condition<EntityT> lessOrEqual(double p) =>
      _op(_ConditionOp.lessOrEq, p, null);

  Condition<EntityT> operator <(double p) => lessThan(p);

  Condition<EntityT> operator >(double p) => greaterThan(p);
}

class QueryBooleanProperty<EntityT> extends QueryProperty<EntityT, bool> {
  QueryBooleanProperty(ModelProperty model) : super(model);

  // ignore: avoid_positional_boolean_parameters
  Condition<EntityT> equals(bool p) =>
      _IntegerCondition<EntityT, bool>(_ConditionOp.eq, this, (p ? 1 : 0));

  // ignore: avoid_positional_boolean_parameters
  Condition<EntityT> notEquals(bool p) =>
      _IntegerCondition<EntityT, bool>(_ConditionOp.notEq, this, (p ? 1 : 0));
}

class QueryStringVectorProperty<EntityT>
    extends QueryProperty<EntityT, List<String>> {
  QueryStringVectorProperty(ModelProperty model) : super(model);

  Condition<EntityT> contains(String p, {bool? caseSensitive}) =>
      _StringCondition<EntityT, List<String>>(
          _ConditionOp.contains, this, p, null,
          caseSensitive: caseSensitive);
}

class QueryRelationProperty<Source, Target>
    extends QueryIntegerProperty<Source> {
  QueryRelationProperty(ModelProperty model) : super(model);
}

class QueryRelationMany<Source, Target> {
  final ModelRelation _model;

  QueryRelationMany(this._model);
}

enum _ConditionOp {
  isNull,
  notNull,
  eq,
  notEq,
  contains,
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
  // using & because && is not overridable
  Condition<EntityT> operator &(Condition<EntityT> rh) => and(rh);

  Condition<EntityT> and(Condition<EntityT> rh) {
    if (this is _ConditionGroupAll) {
      // no need for brackets
      return _ConditionGroupAll<EntityT>(
          [...(this as _ConditionGroupAll<EntityT>)._conditions, rh]);
    }
    return _ConditionGroupAll<EntityT>([this, rh]);
  }

  Condition<EntityT> andAll(List<Condition<EntityT>> rh) =>
      _ConditionGroupAll<EntityT>([this, ...rh]);

  // using | because || is not overridable
  Condition<EntityT> operator |(Condition<EntityT> rh) => or(rh);

  Condition<EntityT> or(Condition<EntityT> rh) {
    if (this is _ConditionGroupAny) {
      // no need for brackets
      return _ConditionGroupAny<EntityT>(
          [...(this as _ConditionGroupAny<EntityT>)._conditions, rh]);
    }
    return _ConditionGroupAny<EntityT>([this, rh]);
  }

  Condition<EntityT> orAny(List<Condition<EntityT>> rh) =>
      _ConditionGroupAny<EntityT>([this, ...rh]);

  int _apply(_QueryBuilder builder, {required bool isRoot});
}

class _NullCondition<EntityT, DartType> extends Condition<EntityT> {
  final QueryProperty<EntityT, DartType> _property;
  final _ConditionOp _op;

  _NullCondition(this._op, this._property);

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

  _PropertyCondition(this._op, this._property, this._value, [this._value2]);
}

class _StringCondition<EntityT, PropertyDartType>
    extends _PropertyCondition<EntityT, PropertyDartType, String> {
  bool? caseSensitive;

  _StringCondition(
      _ConditionOp op,
      QueryProperty<EntityT, PropertyDartType> prop,
      String value,
      String? value2,
      {this.caseSensitive})
      : super(op, prop, value, value2);

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
        final cFn = (_property._model.type == OBXPropertyType.String)
            ? C.qb_contains_string
            : C.qb_any_equals_string;
        return _op1(builder, cFn);
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

  _StringListCondition(
      _ConditionOp op, QueryProperty<EntityT, String> prop, List<String> value,
      {this.caseSensitive})
      : super(op, prop, value);

  int _oneOf(_QueryBuilder builder) {
    final func = C.qb_in_strings;
    final listLength = _value.length;
    final arrayOfCStrings = malloc<Pointer<Int8>>(listLength);
    try {
      for (var i = 0; i < _value.length; i++) {
        arrayOfCStrings[i] = _value[i].toNativeUtf8().cast<Int8>();
      }
      return func(
          builder._cBuilder,
          _property._model.id.id,
          arrayOfCStrings,
          listLength,
          caseSensitive ?? InternalStoreAccess.queryCS(builder._store));
    } finally {
      for (var i = 0; i < _value.length; i++) {
        malloc.free(arrayOfCStrings.elementAt(i).value);
      }
      malloc.free(arrayOfCStrings);
    }
  }

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
      _ConditionOp op, QueryProperty<EntityT, PropertyDartType> prop, int value,
      [int? value2])
      : super(op, prop, value, value2);

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
  _IntegerListCondition(
      _ConditionOp op, QueryProperty<EntityT, int> prop, List<int> value)
      : super(op, prop, value);

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
      double value, double? value2)
      : super(op, prop, value, value2) {
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
  _ByteVectorCondition(
      _ConditionOp op, QueryProperty<EntityT, Uint8List> prop, Uint8List value)
      : super(op, prop, value);

  int _op1(
          _QueryBuilder builder,
          int Function(Pointer<OBX_query_builder>, int, Pointer<Void>, int)
              func) =>
      withNativeBytes(
          _value,
          (Pointer<Void> ptr, int size) =>
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

  _ConditionGroup(this._conditions, this._func);

  @override
  int _apply(_QueryBuilder builder, {required bool isRoot}) {
    final size = _conditions.length;

    if (size == 0) {
      return -1; // -1 instead of 0 which indicates an error
    } else if (size == 1) {
      return _conditions[0]._apply(builder, isRoot: isRoot);
    }

    final intArrayPtr = malloc<Int32>(size);
    try {
      for (var i = 0; i < size; ++i) {
        final cid = _conditions[i]._apply(builder, isRoot: false);
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
  set offset(int offset) => checkObx(C.query_offset(_ptr, offset));

  /// Configure a [limit] for this query.
  ///
  /// All methods that support limit will return/process only the given number
  /// of Objects. Example use case: use together with offset to get a slice of
  /// the whole result, e.g. for "result paging".
  ///
  /// Set limit=0 to reset to the default behavior - no limit applied.
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

  /// Finds Objects matching the query and returns the first result or null
  /// if there are no results. Note: [offset] and [limit] are respected, if set.
  T? findFirst() {
    T? result;
    final visitor = dataVisitor((Pointer<Uint8> data, int size) {
      result = _entity.objectFromFB(_store, data.asTypedList(size));
      return false; // we only want to visit the first element
    });
    _store.runInTransaction(TxMode.read, () {
      checkObx(C.query_visit(_ptr, visitor, nullptr));
    });
    return result;
  }

  /// Finds Objects matching the query and returns their IDs.
  List<int> findIds() {
    final idArrayPtr = checkObxPtr(C.query_find_ids(_ptr), 'find ids');
    try {
      final idArray = idArrayPtr.ref;
      return idArray.count == 0
          ? List<int>.filled(0, 0)
          : idArray.ids.asTypedList(idArray.count).toList(growable: false);
    } finally {
      C.id_array_free(idArrayPtr);
    }
  }

  /// Finds Objects matching the query.
  List<T> find() {
    final result = <T>[];
    final collector = objectCollector(result, _store, _entity);
    _store.runInTransaction(
        TxMode.read, () => checkObx(C.query_visit(_ptr, collector, nullptr)));
    return result;
  }

  /// Finds Objects matching the query, streaming them while the query executes.
  ///
  /// Note: make sure you evaluate performance in your use case - streams come
  /// with an overhead so a plain [find()] is usually faster.
  Stream<T> stream() => _stream1();

  /// Stream items by sending full flatbuffers binary as a message.
  Stream<T> _stream1() {
    initializeDartAPI();
    final port = ReceivePort();
    final cStream = checkObxPtr(
        C.dartc_query_find(_cQuery, port.sendPort.nativePort), 'query stream');

    var closed = false;
    final close = () {
      if (closed) return;
      closed = true;
      C.dartc_stream_close(cStream);
      port.close();
    };

    try {
      final controller = StreamController<T>(onCancel: close);
      port.listen((dynamic message) {
        // We expect Uint8List for data and NULL when the query has finished.
        if (message is Uint8List) {
          try {
            controller.add(_entity.objectFromFB(_store, message));
            return;
          } catch (e) {
            controller.addError(e);
          }
        } else if (message is String) {
          controller.addError(
              ObjectBoxException('Query stream native exception: $message'));
        } else if (message != null) {
          controller.addError(ObjectBoxException(
              'Query stream received an invalid message type '
              '(${message.runtimeType}): $message'));
        }
        controller.close(); // done
        close();
      });
      return controller.stream;
    } catch (e) {
      close();
      rethrow;
    }
  }

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
    final result = PropertyQuery<DartType>._(_ptr, prop._model);
    if (prop._model.type == OBXPropertyType.String) {
      result._caseSensitive = InternalStoreAccess.queryCS(_store);
    }
    return result;
  }
}
