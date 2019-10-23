library query;

import "dart:ffi";

import "../store.dart";
import "../common.dart";
import "../bindings/bindings.dart";
import "../bindings/constants.dart";
import "../bindings/flatbuffers.dart";
import "../bindings/helpers.dart";
import "../bindings/structs.dart";
import "../bindings/signatures.dart";
import "package:ffi/ffi.dart";

part "builder.dart";
part "property.dart";

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

  Condition notEqual(String p, {bool caseSensitive = false}) {
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

  Condition operator ==(String p) => equals(p);
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

  Condition notEqual(int p) {
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
  Condition operator ==(int p) => equals(p);
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
  void operator ==(double p) => DoubleCondition(ConditionOp.eq, this, null, null);
}

class QueryBooleanProperty extends QueryProperty {
  QueryBooleanProperty({int entityId, int propertyId, int obxType}) : super(entityId, propertyId, obxType);

  Condition equals(bool p) {
    return IntegerCondition(ConditionOp.eq, this, (p ? 1 : 0));
  }

  Condition notEqual(bool p) {
    return IntegerCondition(ConditionOp.notEq, this, (p ? 1 : 0));
  }

  Condition operator ==(bool p) => equals(p);
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
    final utf8Str = Utf8.toUtf8(_value);
    try {
      var uint8Str = utf8Str.cast<Uint8>();
      return func(builder._cBuilder, _property._propertyId, uint8Str, _caseSensitive ? 1 : 0);
    } finally {
      utf8Str.free();
    }
  }

  int _inside(QueryBuilder builder) {
    final func = bindings.obx_qb_string_in;
    final listLength = _list.length;
    final arrayOfUint8Ptrs = Pointer<Pointer<Uint8>>.allocate(count: listLength);
    try {
      for (int i = 0; i < _list.length; i++) {
        var uint8Str = Utf8.toUtf8(_list[i]).cast<Uint8>();
        arrayOfUint8Ptrs.elementAt(i).store(uint8Str);
      }
      return func(builder._cBuilder, _property._propertyId, arrayOfUint8Ptrs, listLength, _caseSensitive ? 1 : 0);
    } finally {
      for (int i = 0; i < _list.length; i++) {
        var uint8Str = arrayOfUint8Ptrs.elementAt(i).load();
        uint8Str.free(); // I assume the casted Uint8 retains the same Utf8 address
      }
      arrayOfUint8Ptrs.free(); // It probably doesn't release recursively
    }
  }

  int _opWithEqual(QueryBuilder builder, obx_qb_string_lt_gt_op_dart_t func) {
    final utf8Str = Utf8.toUtf8(_value);
    try {
      var uint8Str = utf8Str.cast<Uint8>();
      return func(builder._cBuilder, _property._propertyId, uint8Str, _caseSensitive ? 1 : 0, _withEqual ? 1 : 0);
    } finally {
      utf8Str.free();
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

  // ideally it should be implemented like this, but this doesn't work, TODO report to google
  /*
  int _opList<P extends NativeType>(QueryBuilder builder, obx_qb_cond_operator_in_dart_t<P> func) {

    int length = _list.length;
    final listPtr = Pointer<P>.allocate(count: length);
    try {
      for (int i=0; i<length; i++) {
        listPtr.elementAt(i).store(_list[i] as int); // Error: Expected type 'P' to be a valid and instantiated subtype of 'NativeType'. // wtf? Compiler bug?
      }
      return func(builder._cBuilder, _property.propertyId, listPtr, length);
    }finally {
      listPtr.free();
    }
  }
  */

  // TODO replace nasty duplication with implementation above, when fix is in
  int _opList32(QueryBuilder builder, obx_qb_cond_operator_in_dart_t<Int32> func) {
    int length = _list.length;
    final listPtr = Pointer<Int32>.allocate(count: length);
    try {
      for (int i = 0; i < length; i++) {
        listPtr.elementAt(i).store(_list[i]);
      }
      return func(builder._cBuilder, _property._propertyId, listPtr, length);
    } finally {
      listPtr.free();
    }
  }

  // TODO replace duplication with implementation above, when fix is in
  int _opList64(QueryBuilder builder, obx_qb_cond_operator_in_dart_t<Int64> func) {
    int length = _list.length;
    final listPtr = Pointer<Int64>.allocate(count: length);
    try {
      for (int i = 0; i < length; i++) {
        listPtr.elementAt(i).store(_list[i]);
      }
      return func(builder._cBuilder, _property._propertyId, listPtr, length);
    } finally {
      listPtr.free();
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

    final intArrayPtr = Pointer<Int32>.allocate(count: size);
    try {
      for (int i = 0; i < size; ++i) {
        final cid = _conditions[i].apply(builder, false);
        if (cid == 0) {
          builder._throwExceptionIfNecessary();
          throw Exception("Failed to create condition " + _conditions[i].toString());
        }

        intArrayPtr.elementAt(i).store(cid);
      }

      // root All (AND) is implicit so no need to actually combine the conditions
      if (isRoot && this is ConditionGroupAll) {
        return -1; // no error but no condition ID either
      }

      return _func(builder._cBuilder, intArrayPtr, size);
    } finally {
      intArrayPtr.free();
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
    _cQuery = checkObxPtr(bindings.obx_query_create(cBuilder), "create query", true);
  }

  int count() {
    final ptr = Pointer<Uint64>.allocate(count: 1);
    try {
      checkObx(bindings.obx_query_count(_cQuery, ptr));
      return ptr.load();
    } finally {
      ptr.free();
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
      OBX_id_array idArray = idArrayPtr.load();
      return idArray.length == 0 ? List<int>() : idArray.items();
    } finally {
      bindings.obx_id_array_free(idArrayPtr);
    }
  }

  List<T> find({int offset = 0, int limit = 0}) {
    return _store.runInTransaction(TxMode.Read, () {
      final bytesArray = checkObxPtr(bindings.obx_query_find(_cQuery, offset, limit), "find");
      try {
        return _fbManager.unmarshalArray(bytesArray);
      } finally {
        bindings.obx_bytes_array_free(bytesArray);
      }
    });
  }

  // For testing purposes
  String describe() {
    return Utf8.fromUtf8(bindings.obx_query_describe(_cQuery).cast<Utf8>());
  }

  // For testing purposes
  String describeParameters() {
    return Utf8.fromUtf8(bindings.obx_query_describe_params(_cQuery).cast<Utf8>());
  }

  /// Not to be confused with QueryProperty...
  PQ property<PQ extends PropertyQuery>(QueryProperty qp) {
    if (OBXPropertyType.Bool <= qp._type && qp._type <= OBXPropertyType.Long) {
      return IntegerPropertyQuery(_cQuery, qp._propertyId, qp._type) as PQ;
    }else if (OBXPropertyType.Float == qp._type || qp._type == OBXPropertyType.Double) {
      return DoublePropertyQuery(_cQuery, qp._propertyId, qp._type) as PQ;
    }else if (OBXPropertyType.String == qp._type) {
      return StringPropertyQuery(_cQuery, qp._propertyId, qp._type) as PQ;
    }else {
      throw Exception("Property query: unsupported type (OBXPropertyType: ${qp._type})");
    }
  }
}
