library query;

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart' show allocate, free, Utf8;

import '../store.dart';
import '../common.dart';
import '../bindings/bindings.dart';
import '../bindings/data_visitor.dart';
import '../bindings/helpers.dart';
import '../bindings/structs.dart';
import '../modelinfo/entity_definition.dart';

part 'builder.dart';

part 'property.dart';

class Order {
  /// Reverts the order from ascending (default) to descending.
  static final descending = 1;

  /// Makes upper case letters (e.g. 'Z') be sorted before lower case letters (e.g. 'a').
  /// If not specified, the default is case insensitive for ASCII characters.
  static final caseSensitive = 2;

  /// For scalars only: changes the comparison to unsigned (default is signed).
  static final unsigned = 4;

  /// null values will be put last.
  /// If not specified, by default null values will be put first.
  static final nullsLast = 8;

  /// null values should be treated equal to zero (scalars only).
  static final nullsAsZero = 16;
}

/// The QueryProperty types are responsible for the operator overloading.
/// A QueryBuilder will be constructed, based on the any / all operations applied.
/// When build() is called on the QueryBuilder a Query object will be created.
class QueryProperty {
  final int _propertyId;
  final int _entityId;
  final int _type;

  QueryProperty(this._entityId, this._propertyId, this._type);

  Condition isNull() {
    return NullCondition(ConditionOp.isNull, this);
  }

  Condition notNull() {
    return NullCondition(ConditionOp.notNull, this);
  }
}

class QueryStringProperty extends QueryProperty {
  QueryStringProperty(
      {/*required*/ int entityId,
      /*required*/ int propertyId,
      /*required*/ int obxType})
      : super(entityId, propertyId, obxType);

  Condition _op(String p, ConditionOp cop, [bool caseSensitive = false]) {
    return StringCondition(cop, this, p, null, caseSensitive);
  }

  Condition _opList(List<String> list, ConditionOp cop,
      [bool caseSensitive = false]) {
    return StringListCondition(cop, this, list, caseSensitive);
  }

  Condition equals(String p, {bool caseSensitive = false}) {
    return _op(p, ConditionOp.eq, caseSensitive);
  }

  Condition notEquals(String p, {bool caseSensitive = false}) {
    return _op(p, ConditionOp.notEq, caseSensitive);
  }

  Condition endsWith(String p, {bool caseSensitive = false}) {
    return _op(p, ConditionOp.endsWith, caseSensitive);
  }

  Condition startsWith(String p, {bool caseSensitive = false}) {
    return _op(p, ConditionOp.startsWith, caseSensitive);
  }

  Condition contains(String p, {bool caseSensitive = false}) {
    return _op(p, ConditionOp.contains, caseSensitive);
  }

  Condition inside(List<String> list, {bool caseSensitive = false}) {
    return _opList(list, ConditionOp.inside, caseSensitive);
  }

  Condition notIn(List<String> list, {bool caseSensitive = false}) {
    return _opList(list, ConditionOp.notIn, caseSensitive);
  }

  Condition greaterThan(String p,
      {bool caseSensitive = false,
      @Deprecated('Use greaterOrEqual() instead') bool withEqual = false}) {
    if (withEqual) {
      return greaterOrEqual(p, caseSensitive: caseSensitive);
    } else {
      return _op(p, ConditionOp.gt, caseSensitive);
    }
  }

  Condition greaterOrEqual(String p, {bool caseSensitive = false}) {
    return _op(p, ConditionOp.greaterOrEq, caseSensitive);
  }

  Condition lessThan(String p,
      {bool caseSensitive = false,
      @Deprecated('Use lessOrEqual() instead') bool withEqual = false}) {
    if (withEqual) {
      return lessOrEqual(p, caseSensitive: caseSensitive);
    } else {
      return _op(p, ConditionOp.lt, caseSensitive);
    }
  }

  Condition lessOrEqual(String p, {bool caseSensitive = false}) {
    return _op(p, ConditionOp.lessOrEq, caseSensitive);
  }

//  Condition operator ==(String p) => equals(p); // see issue #43
//  Condition operator != (String p) => notEqual(p); // not overloadable
}

class QueryByteVectorProperty extends QueryProperty {
  QueryByteVectorProperty(
      {/*required*/ int entityId,
      /*required*/ int propertyId,
      /*required*/ int obxType})
      : super(entityId, propertyId, obxType);

  Condition _op(List<int> val, ConditionOp cop) {
    return ByteVectorCondition(cop, this, Uint8List.fromList(val));
  }

  Condition equals(List<int> val) {
    return _op(val, ConditionOp.eq);
  }

  Condition greaterThan(List<int> val) {
    return _op(val, ConditionOp.gt);
  }

  Condition greaterOrEqual(List<int> val) {
    return _op(val, ConditionOp.greaterOrEq);
  }

  Condition lessThan(List<int> val) {
    return _op(val, ConditionOp.lt);
  }

  Condition lessOrEqual(List<int> val) {
    return _op(val, ConditionOp.lessOrEq);
  }
}

class QueryIntegerProperty extends QueryProperty {
  QueryIntegerProperty(
      {/*required*/ int entityId,
      /*required*/ int propertyId,
      /*required*/ int obxType})
      : super(entityId, propertyId, obxType);

  Condition _op(int p, ConditionOp cop) {
    return IntegerCondition(cop, this, p, 0);
  }

  Condition _opList(List<int> list, ConditionOp cop) {
    return IntegerListCondition(cop, this, list);
  }

  Condition equals(int p) {
    return _op(p, ConditionOp.eq);
  }

  Condition notEquals(int p) {
    return _op(p, ConditionOp.notEq);
  }

  Condition greaterThan(int p) {
    return _op(p, ConditionOp.gt);
  }

  Condition lessThan(int p) {
    return _op(p, ConditionOp.lt);
  }

  Condition operator <(int p) => lessThan(p);

  Condition operator >(int p) => greaterThan(p);

  Condition inside(List<int> list) {
    return _opList(list, ConditionOp.inside);
  }

  Condition notInList(List<int> list) {
    return _opList(list, ConditionOp.notIn);
  }

  Condition notIn(List<int> list) {
    return notInList(list);
  }

// Condition operator != (int p) => notEqual(p); // not overloadable
// Condition operator ==(int p) => equals(p); // see issue #43
}

class QueryDoubleProperty extends QueryProperty {
  QueryDoubleProperty(
      {/*required*/ int entityId,
      /*required*/ int propertyId,
      /*required*/ int obxType})
      : super(entityId, propertyId, obxType);

  Condition _op(ConditionOp op, double p1, double /*?*/ p2) {
    return DoubleCondition(op, this, p1, p2);
  }

  Condition between(double p1, double p2) {
    return _op(ConditionOp.between, p1, p2);
  }

  // NOTE: objectbox-c doesn't support double/float equality (because it's a rather peculiar thing).
  // Therefore, we're currently not providing this in Dart either, not even with some `between()` workarounds.
  // Condition equals(double p) {
  //    _op(ConditionOp.eq, p);
  // }

  Condition greaterThan(double p) {
    return _op(ConditionOp.gt, p, null);
  }

  Condition lessThan(double p) {
    return _op(ConditionOp.lt, p, null);
  }

  Condition operator <(double p) => lessThan(p);

  Condition operator >(double p) => greaterThan(p);

// Note: currently not supported - override the operator and throw explicitly to prevent the default comparison.
// void operator ==(double p) => DoubleCondition(ConditionOp.eq, this, null, null); // see issue #43
}

class QueryBooleanProperty extends QueryProperty {
  QueryBooleanProperty(
      {/*required*/ int entityId,
      /*required*/ int propertyId,
      /*required*/ int obxType})
      : super(entityId, propertyId, obxType);

  Condition equals(bool p) {
    return IntegerCondition(ConditionOp.eq, this, (p ? 1 : 0));
  }

  Condition notEquals(bool p) {
    return IntegerCondition(ConditionOp.notEq, this, (p ? 1 : 0));
  }

// Condition operator ==(bool p) => equals(p); // see issue #43
}

class QueryStringVectorProperty extends QueryProperty {
  QueryStringVectorProperty(
      {/*required*/ int entityId,
      /*required*/ int propertyId,
      /*required*/ int obxType})
      : super(entityId, propertyId, obxType);

  Condition contains(String p, {bool caseSensitive = false}) {
    return StringCondition(ConditionOp.contains, this, p, null, caseSensitive);
  }
}

class QueryRelationProperty<Target> extends QueryIntegerProperty {
  QueryRelationProperty(
      {/*required*/ int entityId,
      /*required*/ int propertyId,
      /*required*/ int obxType})
      : super(entityId: entityId, propertyId: propertyId, obxType: obxType);
}

class QueryRelationMany<Target> {
  final int _entityId;
  final int _relationId;

  QueryRelationMany(
      {/*required*/ int entityId,
      /*required*/ int relationId})
      : _entityId = entityId,
        _relationId = relationId;
}

enum ConditionOp {
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
  inside,
  notIn,
  between,
}

abstract class Condition {
  // using & because && is not overridable
  Condition operator &(Condition rh) => and(rh);

  Condition and(Condition rh) {
    if (this is ConditionGroupAll) {
      // no need for brackets
      return ConditionGroupAll(
          [...(this as ConditionGroupAll)._conditions, rh]);
    }
    return ConditionGroupAll([this, rh]);
  }

  Condition andAll(List<Condition> rh) {
    return ConditionGroupAll([this, ...rh]);
  }

  // using | because || is not overridable
  Condition operator |(Condition rh) => or(rh);

  Condition or(Condition rh) {
    if (this is ConditionGroupAny) {
      // no need for brackets
      return ConditionGroupAny(
          [...(this as ConditionGroupAny)._conditions, rh]);
    }
    return ConditionGroupAny([this, rh]);
  }

  Condition orAny(List<Condition> rh) {
    return ConditionGroupAny([this, ...rh]);
  }

  int apply(_QueryBuilder builder, bool isRoot);
}

class NullCondition extends Condition {
  final QueryProperty _property;
  final ConditionOp _op;

  NullCondition(this._op, this._property);

  @override
  int apply(_QueryBuilder builder, bool isRoot) {
    switch (_op) {
      case ConditionOp.isNull:
        return bindings.obx_qb_null(builder._cBuilder, _property._propertyId);
      case ConditionOp.notNull:
        return bindings.obx_qb_not_null(
            builder._cBuilder, _property._propertyId);
      default:
        throw Exception('Unsupported operation ${_op.toString()}');
    }
  }
}

abstract class PropertyCondition<DartType> extends Condition {
  final QueryProperty _property;
  final DartType _value;
  final DartType /*?*/ _value2;

  final ConditionOp _op;

  PropertyCondition(this._op, this._property, this._value, [this._value2]);
}

class StringCondition extends PropertyCondition<String> {
  final bool _caseSensitive;

  StringCondition(ConditionOp op, QueryProperty prop, String value,
      String /*?*/ value2, bool caseSensitive)
      : _caseSensitive = caseSensitive,
        super(op, prop, value, value2);

  int _op1(_QueryBuilder builder,
      int Function(Pointer<OBX_query_builder>, int, Pointer<Int8>, bool) func) {
    final cStr = Utf8.toUtf8(_value).cast<Int8>();
    try {
      return func(
          builder._cBuilder, _property._propertyId, cStr, _caseSensitive);
    } finally {
      free(cStr);
    }
  }

  @override
  int apply(_QueryBuilder builder, bool isRoot) {
    switch (_op) {
      case ConditionOp.eq:
        return _op1(builder, bindings.obx_qb_equals_string);
      case ConditionOp.notEq:
        return _op1(builder, bindings.obx_qb_not_equals_string);
      case ConditionOp.contains:
        final cFn = (_property._type == OBXPropertyType.String)
            ? bindings.obx_qb_contains_string
            : bindings.obx_qb_any_equals_string;
        return _op1(builder, cFn);
      case ConditionOp.startsWith:
        return _op1(builder, bindings.obx_qb_starts_with_string);
      case ConditionOp.endsWith:
        return _op1(builder, bindings.obx_qb_ends_with_string);
      case ConditionOp.lt:
        return _op1(builder, bindings.obx_qb_less_than_string);
      case ConditionOp.lessOrEq:
        return _op1(builder, bindings.obx_qb_less_or_equal_string);
      case ConditionOp.gt:
        return _op1(builder, bindings.obx_qb_greater_than_string);
      case ConditionOp.greaterOrEq:
        return _op1(builder, bindings.obx_qb_greater_or_equal_string);
      default:
        throw Exception('Unsupported operation ${_op.toString()}');
    }
  }
}

class StringListCondition extends PropertyCondition<List<String>> {
  final bool _caseSensitive;

  StringListCondition(ConditionOp op, QueryProperty prop, List<String> value,
      bool caseSensitive)
      : _caseSensitive = caseSensitive,
        super(op, prop, value);

  int _inside(_QueryBuilder builder) {
    final func = bindings.obx_qb_in_strings;
    final listLength = _value.length;
    final arrayOfCStrings = allocate<Pointer<Int8>>(count: listLength);
    try {
      for (var i = 0; i < _value.length; i++) {
        arrayOfCStrings[i] = Utf8.toUtf8(_value[i]).cast<Int8>();
      }
      return func(builder._cBuilder, _property._propertyId, arrayOfCStrings,
          listLength, _caseSensitive);
    } finally {
      for (var i = 0; i < _value.length; i++) {
        free(arrayOfCStrings.elementAt(i).value);
      }
      free(arrayOfCStrings);
    }
  }

  @override
  int apply(_QueryBuilder builder, bool isRoot) {
    switch (_op) {
      case ConditionOp.inside:
        return _inside(builder); // bindings.obx_qb_string_in
      default:
        throw Exception('Unsupported operation ${_op.toString()}');
    }
  }
}

class IntegerCondition extends PropertyCondition<int> {
  IntegerCondition(ConditionOp op, QueryProperty prop, int value,
      [int /*?*/ value2])
      : super(op, prop, value, value2);

  int _op1(_QueryBuilder builder,
      int Function(Pointer<OBX_query_builder>, int, int /*?*/) func) {
    return func(builder._cBuilder, _property._propertyId, _value);
  }

  @override
  int apply(_QueryBuilder builder, bool isRoot) {
    switch (_op) {
      case ConditionOp.eq:
        return _op1(builder, bindings.obx_qb_equals_int);
      case ConditionOp.notEq:
        return _op1(builder, bindings.obx_qb_not_equals_int);
      case ConditionOp.gt:
        return _op1(builder, bindings.obx_qb_greater_than_int);
      case ConditionOp.lt:
        return _op1(builder, bindings.obx_qb_less_than_int);
      case ConditionOp.between:
        return bindings.obx_qb_between_2ints(
            builder._cBuilder, _property._propertyId, _value, _value2);
      default:
        throw Exception('Unsupported operation ${_op.toString()}');
    }
  }
}

class IntegerListCondition extends PropertyCondition<List<int>> {
  IntegerListCondition(ConditionOp op, QueryProperty prop, List<int> value)
      : super(op, prop, value);

  int _opList<T extends NativeType>(
      _QueryBuilder builder,
      int Function(Pointer<OBX_query_builder>, int, Pointer<T>, int) func,
      void Function(Pointer<T>, int, int) setIndex) {
    final length = _value.length;
    final listPtr = allocate<T>(count: length);
    try {
      for (var i = 0; i < length; i++) {
        // Error: The operator '[]=' isn't defined for the type 'Pointer<T>
        // listPtr[i] = _list[i];
        setIndex(listPtr, i, _value[i]);
      }
      return func(builder._cBuilder, _property._propertyId, listPtr, length);
    } finally {
      free(listPtr);
    }
  }

  static void opListSetIndexInt32(Pointer<Int32> list, i, val) => list[i] = val;

  static void opListSetIndexInt64(Pointer<Int64> list, i, val) => list[i] = val;

  @override
  int apply(_QueryBuilder builder, bool isRoot) {
    switch (_op) {
      case ConditionOp.inside:
        switch (_property._type) {
          case OBXPropertyType.Int:
            return _opList(
                builder, bindings.obx_qb_in_int32s, opListSetIndexInt32);
          case OBXPropertyType.Long:
            return _opList(
                builder, bindings.obx_qb_in_int64s, opListSetIndexInt64);
          default:
            throw Exception('Unsupported type for IN: ${_property._type}');
        }
        break;
      case ConditionOp.notIn:
        switch (_property._type) {
          case OBXPropertyType.Int:
            return _opList(
                builder, bindings.obx_qb_not_in_int32s, opListSetIndexInt32);
          case OBXPropertyType.Long:
            return _opList(
                builder, bindings.obx_qb_not_in_int64s, opListSetIndexInt64);
          default:
            throw Exception('Unsupported type for IN: ${_property._type}');
        }
        break;
      default:
        throw Exception('Unsupported operation ${_op.toString()}');
    }
  }
}

class DoubleCondition extends PropertyCondition<double> {
  DoubleCondition(
      ConditionOp op, QueryProperty prop, double value, double /*?*/ value2)
      : super(op, prop, value, value2) {
    assert(op != ConditionOp.eq,
        'Equality operator is not supported on floating point numbers - use between() instead.');
  }

  @override
  int apply(_QueryBuilder builder, bool isRoot) {
    switch (_op) {
      case ConditionOp.gt:
        return bindings.obx_qb_greater_than_double(
            builder._cBuilder, _property._propertyId, _value);
      case ConditionOp.lt:
        return bindings.obx_qb_less_than_double(
            builder._cBuilder, _property._propertyId, _value);
      case ConditionOp.between:
        return bindings.obx_qb_between_2doubles(
            builder._cBuilder, _property._propertyId, _value, _value2);
      default:
        throw Exception('Unsupported operation ${_op.toString()}');
    }
  }
}

class ByteVectorCondition extends PropertyCondition<Uint8List> {
  ByteVectorCondition(ConditionOp op, QueryProperty prop, Uint8List value)
      : super(op, prop, value);

  int _op1(_QueryBuilder builder,
      int Function(Pointer<OBX_query_builder>, int, Pointer<Void>, int) func) {
    final cBytes = OBX_bytes_wrapper.managedCopyOf(_value, align: false);
    try {
      return func(
          builder._cBuilder, _property._propertyId, cBytes.ptr, cBytes.size);
    } finally {
      cBytes.freeManaged();
    }
  }

  @override
  int apply(_QueryBuilder builder, bool isRoot) {
    switch (_op) {
      case ConditionOp.eq:
        return _op1(builder, bindings.obx_qb_equals_bytes);
      case ConditionOp.lt:
        return _op1(builder, bindings.obx_qb_less_than_bytes);
      case ConditionOp.lessOrEq:
        return _op1(builder, bindings.obx_qb_less_or_equal_bytes);
      case ConditionOp.gt:
        return _op1(builder, bindings.obx_qb_greater_than_bytes);
      case ConditionOp.greaterOrEq:
        return _op1(builder, bindings.obx_qb_greater_or_equal_bytes);
      default:
        throw Exception('Unsupported operation ${_op.toString()}');
    }
  }
}

class ConditionGroup extends Condition {
  final List<Condition> _conditions;
  final int Function(Pointer<OBX_query_builder>, Pointer<Int32>, int) _func;

  ConditionGroup(this._conditions, this._func);

  @override
  int apply(_QueryBuilder builder, bool isRoot) {
    final size = _conditions.length;

    if (size == 0) {
      return -1; // -1 instead of 0 which indicates an error
    } else if (size == 1) {
      return _conditions[0].apply(builder, isRoot);
    }

    final intArrayPtr = allocate<Int32>(count: size);
    try {
      for (var i = 0; i < size; ++i) {
        final cid = _conditions[i].apply(builder, false);
        if (cid == 0) {
          builder._throwExceptionIfNecessary();
          throw Exception(
              'Failed to create condition ' + _conditions[i].toString());
        }

        intArrayPtr[i] = cid;
      }

      // root All (AND) is implicit so no need to actually combine the conditions
      if (isRoot && this is ConditionGroupAll) {
        return -1; // no error but no condition ID either
      }

      return _func(builder._cBuilder, intArrayPtr, size);
    } finally {
      free(intArrayPtr);
    }
  }
}

class ConditionGroupAny extends ConditionGroup {
  ConditionGroupAny(conditions) : super(conditions, bindings.obx_qb_any);
}

class ConditionGroupAll extends ConditionGroup {
  ConditionGroupAll(conditions) : super(conditions, bindings.obx_qb_all);
}

/// A repeatable Query returning the latest matching Objects.
///
/// Use [find] or related methods to fetch the latest results from the BoxStore.
///
/// Use [property] to only return values or an aggregate of a single Property.
class Query<T> {
  final Pointer<OBX_query> _cQuery;
  final Store store;
  final EntityDefinition<T> _entity;

  int get entityId => _entity.model.id.id;

  Query._(this.store, Pointer<OBX_query_builder> cBuilder, this._entity)
      : _cQuery = checkObxPtr(bindings.obx_query(cBuilder), 'create query');

  /// Configure an [offset] for this query.
  ///
  /// All methods that support offset will return/process Objects starting at
  /// this offset. Example use case: use together with limit to get a slice of
  /// the whole result, e.g. for "result paging".
  ///
  /// Call with offset=0 to reset to the default behavior,
  /// i.e. starting from the first element.
  Query<T> offset(int offset) {
    checkObx(bindings.obx_query_offset(_cQuery, offset));
    return this;
  }

  /// Configure a [limit] for this query.
  ///
  /// All methods that support limit will return/process only the given number
  /// of Objects. Example use case: use together with offset to get a slice of
  /// the whole result, e.g. for "result paging".
  ///
  /// Call with limit=0 to reset to the default behavior -
  /// zero limit means no limit applied.
  Query<T> limit(int limit) {
    checkObx(bindings.obx_query_limit(_cQuery, limit));
    return this;
  }

  /// Returns the number of matching Objects.
  int count() {
    final ptr = allocate<Uint64>();
    try {
      checkObx(bindings.obx_query_count(_cQuery, ptr));
      return ptr.value;
    } finally {
      free(ptr);
    }
  }

  /// Returns the number of removed Objects.
  int remove() {
    final ptr = allocate<Uint64>();
    try {
      checkObx(bindings.obx_query_remove(_cQuery, ptr));
      return ptr.value;
    } finally {
      free(ptr);
    }
  }

  /// Close the query and free resources.
  // TODO Document wrap with closure to fake auto close
  void close() {
    checkObx(bindings.obx_query_close(_cQuery));
  }

  /// Finds Objects matching the query and returns the first result or null
  /// if there are no results.
  /// Warning: this implicitly sets offset=0 & limit=1 and leaves them set.
  /// In the future, this behaviour will change.
  T /*?*/ findFirst() {
    // TODO move to the core to avoid side-effects
    offset(0);
    limit(1);
    final list = find();
    return (list.isEmpty ? null : list[0]);
  }

  /// Finds Objects matching the query and returns their IDs.
  List<int> findIds(
      {@Deprecated('Use offset() instead') int offset = 0,
      @Deprecated('Use limit() instead') int limit = 0}) {
    if (offset > 0) {
      this.offset(offset);
    }
    if (limit > 0) {
      this.limit(limit);
    }
    final idArrayPtr =
        checkObxPtr(bindings.obx_query_find_ids(_cQuery), 'find ids');
    try {
      final idArray = idArrayPtr.ref;
      return idArray.count == 0
          ? List<int>.empty()
          : idArray.ids.asTypedList(idArray.count).toList(growable: false);
    } finally {
      bindings.obx_id_array_free(idArrayPtr);
    }
  }

  /// Finds Objects matching the query.
  List<T> find(
      {@Deprecated('Use offset() instead') int offset = 0,
      @Deprecated('Use limit() instead') int limit = 0}) {
    if (offset > 0) {
      this.offset(offset);
    }
    if (limit > 0) {
      this.limit(limit);
    }
    return store.runInTransaction(TxMode.Read, () {
      final collector = ObjectCollector<T>(store, _entity);
      try {
        checkObx(bindings.obx_query_visit(
            _cQuery, collector.fn, collector.userData));
      } finally {
        collector.close();
      }
      return collector.list;
    });
  }

  /// For internal testing purposes.
  String describe() {
    return cString(bindings.obx_query_describe(_cQuery));
  }

  /// For internal testing purposes.
  String describeParameters() {
    return cString(bindings.obx_query_describe_params(_cQuery));
  }

  /// Creates a property query for the given property [qp].
  ///
  /// Uses the same conditions as this query, but results only include the values of the given property.
  /// To obtain results cast the returned [PropertyQuery] to a specific type.
  ///
  /// ```dart
  /// var q = query.property(tInteger) as IntegerPropertyQuery;
  /// var results = q.find()
  /// ```
  ///
  /// Alternatively call a type-specific function.
  /// ```dart
  /// var q = query.integerProperty(tInteger);
  /// ```
  PQ property<PQ extends PropertyQuery>(QueryProperty qp) {
    if (OBXPropertyType.Bool <= qp._type && qp._type <= OBXPropertyType.Long) {
      return IntegerPropertyQuery(_cQuery, qp._propertyId, qp._type) as PQ;
    } else if (OBXPropertyType.Float == qp._type ||
        qp._type == OBXPropertyType.Double) {
      return DoublePropertyQuery(_cQuery, qp._propertyId, qp._type) as PQ;
    } else if (OBXPropertyType.String == qp._type) {
      return StringPropertyQuery(_cQuery, qp._propertyId, qp._type) as PQ;
    } else {
      throw Exception(
          'Property query: unsupported type (OBXPropertyType: ${qp._type})');
    }
  }

  /// See [property] for details.
  IntegerPropertyQuery integerProperty(QueryProperty qp) {
    return property<IntegerPropertyQuery>(qp);
  }

  /// See [property] for details.
  DoublePropertyQuery doubleProperty(QueryProperty qp) {
    return property<DoublePropertyQuery>(qp);
  }

  /// See [property] for details.
  StringPropertyQuery stringProperty(QueryProperty qp) {
    return property<StringPropertyQuery>(qp);
  }
}
