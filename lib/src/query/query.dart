library query;

import "dart:ffi";
import "package:ffi/ffi.dart" show allocate, free, Utf8;

import "../store.dart";
import "../common.dart";
import "../bindings/bindings.dart";
import "../bindings/constants.dart";
import "../bindings/data_visitor.dart";
import "../bindings/flatbuffers.dart";
import "../bindings/helpers.dart";
import "../bindings/structs.dart";
import "../bindings/signatures.dart";

part "builder.dart";

class Order {
  /// Reverts the order from ascending (default) to descending.
  static final descending = 1;

  /// Makes upper case letters (e.g. "Z") be sorted before lower case letters (e.g. "a").
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
  int _propertyId, _entityId, _type;

  QueryProperty(this._entityId, this._propertyId, this._type);

  Condition isNull() {
    // the integer serves as a dummy type, to initialize the base type
    return IntegerCondition(ConditionOp.isNull, this, null, null);
  }

  Condition notNull() {
    return IntegerCondition(ConditionOp.notNull, this, null, null);
  }
}

class QueryStringProperty extends QueryProperty {
  QueryStringProperty({int entityId, int propertyId, int obxType}) : super(entityId, propertyId, obxType);

  Condition _op(String p, ConditionOp cop, [bool caseSensitive = false, bool descending = false]) {
    return StringCondition(cop, this, p, null, caseSensitive, descending);
  }

  Condition _opWithEqual(String p, ConditionOp cop, [bool caseSensitive = false, bool withEqual = false]) {
    return StringCondition._withEqual(cop, this, p, caseSensitive, withEqual);
  }

  Condition _opList(List<String> list, ConditionOp cop, [bool caseSensitive = false]) {
    return StringCondition._fromList(cop, this, list, caseSensitive);
  }

  Condition equals(String p, {bool caseSensitive = false}) {
    return _op(p, ConditionOp.eq, caseSensitive, false);
  }

  Condition notEquals(String p, {bool caseSensitive = false}) {
    return _op(p, ConditionOp.notEq, caseSensitive, false);
  }

  Condition endsWith(String p, {bool descending = false}) {
    return _op(p, ConditionOp.stringEnds, false, descending);
  }

  Condition startsWith(String p, {bool descending = false}) {
    return _op(p, ConditionOp.stringStarts, false, descending);
  }

  Condition contains(String p, {bool caseSensitive = false}) {
    return _op(p, ConditionOp.stringContains, caseSensitive, false);
  }

  Condition inside(List<String> list, {bool caseSensitive = false}) {
    return _opList(list, ConditionOp.inside, caseSensitive);
  }

  Condition notIn(List<String> list, {bool caseSensitive = false}) {
    return _opList(list, ConditionOp.notIn, caseSensitive);
  }

  Condition greaterThan(String p, {bool caseSensitive = false, bool withEqual = false}) {
    return _opWithEqual(p, ConditionOp.gt, caseSensitive, withEqual);
  }

  Condition lessThan(String p, {bool caseSensitive = false, bool withEqual = false}) {
    return _opWithEqual(p, ConditionOp.lt, caseSensitive, withEqual);
  }

//  Condition operator ==(String p) => equals(p); // see issue #43
//  Condition operator != (String p) => notEqual(p); // not overloadable
}

class QueryIntegerProperty extends QueryProperty {
  QueryIntegerProperty({int entityId, int propertyId, int obxType}) : super(entityId, propertyId, obxType);

  Condition _op(int p, ConditionOp cop) {
    return IntegerCondition(cop, this, p, 0);
  }

  Condition _opList(List<int> list, ConditionOp cop) {
    return IntegerCondition.fromList(cop, this, list);
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
  QueryDoubleProperty({int entityId, int propertyId, int obxType}) : super(entityId, propertyId, obxType);

  Condition _op(ConditionOp op, double p1, double p2) {
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
  QueryBooleanProperty({int entityId, int propertyId, int obxType}) : super(entityId, propertyId, obxType);

  Condition equals(bool p) {
    return IntegerCondition(ConditionOp.eq, this, (p ? 1 : 0));
  }

  Condition notEquals(bool p) {
    return IntegerCondition(ConditionOp.notEq, this, (p ? 1 : 0));
  }

// Condition operator ==(bool p) => equals(p); // see issue #43
}

enum ConditionOp {
  isNull,
  notNull,
  eq,
  notEq,
  stringContains,
  stringStarts,
  stringEnds,
  gt,
  lt,
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
      return ConditionGroupAll([...(this as ConditionGroupAll)._conditions, rh]);
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
      return ConditionGroupAny([...(this as ConditionGroupAny)._conditions, rh]);
    }
    return ConditionGroupAny([this, rh]);
  }

  Condition orAny(List<Condition> rh) {
    return ConditionGroupAny([this, ...rh]);
  }

  int apply(QueryBuilder builder, bool isRoot);
}

abstract class PropertyCondition<DartType> extends Condition {
  QueryProperty _property;
  DartType _value, _value2;
  List<DartType> _list;

  ConditionOp _op;

  PropertyCondition(this._op, this._property, this._value, [this._value2]);

  PropertyCondition.fromList(this._op, this._property, this._list);

  int tryApply(QueryBuilder builder) {
    switch (_op) {
      case ConditionOp.isNull:
        return bindings.obx_qb_null(builder._cBuilder, _property._propertyId);
      case ConditionOp.notNull:
        return bindings.obx_qb_not_null(builder._cBuilder, _property._propertyId);
      default:
        return 0;
    }
  }
}

class StringCondition extends PropertyCondition<String> {
  bool _caseSensitive, _withEqual;

  StringCondition(ConditionOp op, QueryProperty prop, String value,
      [String value2, bool caseSensitive, bool descending])
      : super(op, prop, value, value2) {
    _caseSensitive = caseSensitive;
  }

  StringCondition._fromList(ConditionOp op, QueryProperty prop, List<String> list, bool caseSensitive)
      : super.fromList(op, prop, list) {
    _caseSensitive = caseSensitive;
  }

  StringCondition._withEqual(ConditionOp op, QueryProperty prop, String value, bool caseSensitive, bool withEqual)
      : super(op, prop, value) {
    _caseSensitive = caseSensitive;
    _withEqual = withEqual;
  }

  int _op1(QueryBuilder builder, obx_qb_cond_string_op_1_dart_t func) {
    final cStr = Utf8.toUtf8(_value);
    try {
      return func(builder._cBuilder, _property._propertyId, cStr, _caseSensitive ? 1 : 0);
    } finally {
      free(cStr);
    }
  }

  int _inside(QueryBuilder builder) {
    final func = bindings.obx_qb_string_in;
    final listLength = _list.length;
    final arrayOfCStrings = allocate<Pointer<Utf8>>(count: listLength);
    try {
      for (int i = 0; i < _list.length; i++) {
        arrayOfCStrings[i] = Utf8.toUtf8(_list[i]);
      }
      return func(builder._cBuilder, _property._propertyId, arrayOfCStrings, listLength, _caseSensitive ? 1 : 0);
    } finally {
      for (int i = 0; i < _list.length; i++) {
        free(arrayOfCStrings.elementAt(i).value);
      }
      free(arrayOfCStrings);
    }
  }

  int _opWithEqual(QueryBuilder builder, obx_qb_string_lt_gt_op_dart_t func) {
    final cStr = Utf8.toUtf8(_value);
    try {
      return func(builder._cBuilder, _property._propertyId, cStr, _caseSensitive ? 1 : 0, _withEqual ? 1 : 0);
    } finally {
      free(cStr);
    }
  }

  int apply(QueryBuilder builder, bool isRoot) {
    final c = tryApply(builder);
    if (c != 0) {
      return c;
    }

    switch (_op) {
      case ConditionOp.eq:
        return _op1(builder, bindings.obx_qb_string_equal);
      case ConditionOp.notEq:
        return _op1(builder, bindings.obx_qb_string_not_equal);
      case ConditionOp.stringContains:
        return _op1(builder, bindings.obx_qb_string_contains);
      case ConditionOp.stringStarts:
        return _op1(builder, bindings.obx_qb_string_starts_with);
      case ConditionOp.stringEnds:
        return _op1(builder, bindings.obx_qb_string_ends_with);
      case ConditionOp.lt:
        return _opWithEqual(builder, bindings.obx_qb_string_less);
      case ConditionOp.gt:
        return _opWithEqual(builder, bindings.obx_qb_string_greater);
      case ConditionOp.inside:
        return _inside(builder); // bindings.obx_qb_string_in
      default:
        throw Exception("Unsupported operation ${_op.toString()}");
    }
  }
}

class IntegerCondition extends PropertyCondition<int> {
  IntegerCondition(ConditionOp op, QueryProperty prop, int value, [int value2]) : super(op, prop, value, value2);

  IntegerCondition.fromList(ConditionOp op, QueryProperty prop, List<int> list) : super.fromList(op, prop, list);

  int _op1(QueryBuilder builder, obx_qb_cond_operator_1_dart_t<int> func) {
    return func(builder._cBuilder, _property._propertyId, _value);
  }

  // ideally it should be implemented like this, but this doesn't work, TODO report to google, doesn't work with 2.6 yet
  /*
  int _opList<P extends NativeType>(QueryBuilder builder, obx_qb_cond_operator_in_dart_t<P> func) {

    int length = _list.length;
    final listPtr = allocate<P>(count: length);
    try {
      for (int i=0; i<length; i++) {
        listPtr[i] = _list[i] as int; // Error: Expected type 'P' to be a valid and instantiated subtype of 'NativeType'. // wtf? Compiler bug?
      }
      return func(builder._cBuilder, _property.propertyId, listPtr, length);
    }finally {
      free(listPtr);
    }
  }
  */

  // TODO replace nasty duplication with implementation above, when fix is in
  int _opList32(QueryBuilder builder, obx_qb_cond_operator_in_dart_t<Int32> func) {
    int length = _list.length;
    final listPtr = allocate<Int32>(count: length);
    try {
      for (int i = 0; i < length; i++) {
        listPtr[i] = _list[i];
      }
      return func(builder._cBuilder, _property._propertyId, listPtr, length);
    } finally {
      free(listPtr);
    }
  }

  // TODO replace duplication with implementation above, when fix is in
  int _opList64(QueryBuilder builder, obx_qb_cond_operator_in_dart_t<Int64> func) {
    int length = _list.length;
    final listPtr = allocate<Int64>(count: length);
    try {
      for (int i = 0; i < length; i++) {
        listPtr[i] = _list[i];
      }
      return func(builder._cBuilder, _property._propertyId, listPtr, length);
    } finally {
      free(listPtr);
    }
  }

  int apply(QueryBuilder builder, bool isRoot) {
    final c = tryApply(builder);
    if (c != 0) {
      return c;
    }

    switch (_op) {
      case ConditionOp.eq:
        return _op1(builder, bindings.obx_qb_int_equal);
      case ConditionOp.notEq:
        return _op1(builder, bindings.obx_qb_int_not_equal);
      case ConditionOp.gt:
        return _op1(builder, bindings.obx_qb_int_greater);
      case ConditionOp.lt:
        return _op1(builder, bindings.obx_qb_int_less);
      case ConditionOp.between:
        return bindings.obx_qb_int_between(builder._cBuilder, _property._propertyId, _value, _value2);
      case ConditionOp.inside:
        switch (_property._type) {
          case OBXPropertyType.Int:
            return _opList32(builder, bindings.obx_qb_int32_in);
          case OBXPropertyType.Long:
            return _opList64(builder, bindings.obx_qb_int64_in);
          default:
            throw Exception("Unsupported type for IN: ${_property._type}");
        }
        break;
      case ConditionOp.notIn:
        switch (_property._type) {
          case OBXPropertyType.Int:
            return _opList32(builder, bindings.obx_qb_int32_not_in);
          case OBXPropertyType.Long:
            return _opList64(builder, bindings.obx_qb_int64_not_in);
          default:
            throw Exception("Unsupported type for IN: ${_property._type}");
        }
        break;
      default:
        throw Exception("Unsupported operation ${_op.toString()}");
    }
  }
}

class DoubleCondition extends PropertyCondition<double> {
  DoubleCondition(ConditionOp op, QueryProperty prop, double value, double value2) : super(op, prop, value, value2) {
    assert(
        op != ConditionOp.eq, "Equality operator is not supported on floating point numbers - use between() instead.");
  }

  int _op1(QueryBuilder builder, obx_qb_cond_operator_1_dart_t<double> func) {
    return func(builder._cBuilder, _property._propertyId, _value);
  }

  int apply(QueryBuilder builder, bool isRoot) {
    final c = tryApply(builder);
    if (c != 0) {
      return c;
    }

    switch (_op) {
      case ConditionOp.gt:
        return _op1(builder, bindings.obx_qb_double_greater);
      case ConditionOp.lt:
        return _op1(builder, bindings.obx_qb_double_less);
      case ConditionOp.between:
        return bindings.obx_qb_double_between(builder._cBuilder, _property._propertyId, _value, _value2);
      default:
        throw Exception("Unsupported operation ${_op.toString()}");
    }
  }
}

class ConditionGroup extends Condition {
  List<Condition> _conditions;
  obx_qb_join_op_dart_t _func;

  ConditionGroup(this._conditions, this._func);

  int apply(QueryBuilder builder, bool isRoot) {
    final size = _conditions.length;

    if (size == 0) {
      return -1; // -1 instead of 0 which indicates an error
    } else if (size == 1) {
      return _conditions[0].apply(builder, isRoot);
    }

    final intArrayPtr = allocate<Int32>(count: size);
    try {
      for (int i = 0; i < size; ++i) {
        final cid = _conditions[i].apply(builder, false);
        if (cid == 0) {
          builder._throwExceptionIfNecessary();
          throw Exception("Failed to create condition " + _conditions[i].toString());
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

class Query<T> {
  Pointer<Void> _cQuery;
  Store _store;
  OBXFlatbuffersManager _fbManager;

  // package private ctor
  Query._(this._store, this._fbManager, Pointer<Void> cBuilder) {
    _cQuery = checkObxPtr(bindings.obx_query_create(cBuilder), "create query");
  }

  int count() {
    final ptr = allocate<Uint64>(count: 1);
    try {
      checkObx(bindings.obx_query_count(_cQuery, ptr));
      return ptr.value;
    } finally {
      free(ptr);
    }
  }

  // TODO Document wrap with closure to fake auto close
  void close() {
    checkObx(bindings.obx_query_close(_cQuery));
  }

  T findFirst() {
    final list = find(offset: 0, limit: 1);
    return (list.isEmpty ? null : list[0]);
  }

  List<int> findIds({int offset = 0, int limit = 0}) {
    final idArrayPtr = checkObxPtr(bindings.obx_query_find_ids(_cQuery, offset, limit), "find ids");
    try {
      OBX_id_array idArray = idArrayPtr.ref;
      return idArray.length == 0 ? List<int>() : idArray.items();
    } finally {
      bindings.obx_id_array_free(idArrayPtr);
    }
  }

  List<T> find({int offset = 0, int limit = 0}) {
    return _store.runInTransaction(TxMode.Read, () {
      if (bindings.obx_supports_bytes_array() == 1) {
        final bytesArray = checkObxPtr(bindings.obx_query_find(_cQuery, offset, limit), "find");
        try {
          return _fbManager.unmarshalArray(bytesArray);
        } finally {
          bindings.obx_bytes_array_free(bytesArray);
        }
      } else {
        final results = <T>[];
        final visitor = DataVisitor((Pointer<Uint8> dataPtr, int length) {
          final bytes = dataPtr.asTypedList(length);
          results.add(_fbManager.unmarshal(bytes));
          return true;
        });

        final err = bindings.obx_query_visit(_cQuery, visitor.fn, visitor.userData, offset, limit);
        visitor.close();
        checkObx(err);
        return results;
      }
    });
  }

  // For testing purposes
  String describe() {
    return cString(bindings.obx_query_describe(_cQuery));
  }

  // For testing purposes
  String describeParameters() {
    return cString(bindings.obx_query_describe_params(_cQuery));
  }
}
