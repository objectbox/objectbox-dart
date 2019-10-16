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

/**
 * The QueryProperty types are responsible
 * for the operator overloading.
 *
 * A QueryBuilder will be constructed,
 * based on the any / all operations applied.
 *
 * When build() is called on the QueryBuilder
 * a Query object will be created.
 */
class QueryProperty {
  int propertyId, entityId, type;
  QueryProperty(this.entityId, this.propertyId, this.type);

  ConditionGroup isNull() {
    // the integer serves as a dummy type, to initialize the base type
    final c = IntegerCondition(ConditionOp.isNull, type, null, null);
    return new ConditionGroup(entityId, propertyId, c);
  }

  ConditionGroup notNull() {
    final c = IntegerCondition(ConditionOp.notNull, type, null, null);
    return new ConditionGroup(entityId, propertyId, c);
  }
}

class QueryStringProperty extends QueryProperty {
  QueryStringProperty({int entityId, int propertyId, int obxType}) : super(entityId, propertyId, obxType);

  ConditionGroup _op(String p, ConditionOp cop, [bool caseSensitive = false, bool descending = false]) {
    final c = StringCondition(cop, type, p, null, caseSensitive, descending);
    return ConditionGroup(entityId, propertyId, c);
  }

  ConditionGroup _opWithEqual(String p, ConditionOp cop, [bool caseSensitive = false, bool withEqual = false]) {
    final c = StringCondition._withEqual(cop, type, p, caseSensitive, withEqual);
    return ConditionGroup(entityId, propertyId, c);
  }

  ConditionGroup _opList(List<String> list, ConditionOp cop, [bool caseSensitive = false]) {
    final c = StringCondition._fromList(cop, type, list, caseSensitive);
    return ConditionGroup(entityId, propertyId, c);
  }

  ConditionGroup equals(String p, {bool caseSensitive = false}) {
    return _op(p, ConditionOp.eq, caseSensitive, false);
  }

  ConditionGroup notEqual(String p, {bool caseSensitive = false}) {
    return _op(p, ConditionOp.notEq, caseSensitive, false);
  }

  ConditionGroup endsWith(String p, {bool descending = false}) {
    return _op(p, ConditionOp.stringEnds, false, descending);
  }

  ConditionGroup startsWith(String p, {bool descending = false}) {
    return _op(p, ConditionOp.stringStarts, false, descending);
  }

  ConditionGroup contains(String p, {bool caseSensitive = false}) {
    return _op(p, ConditionOp.stringContains, caseSensitive, false);
  }

  ConditionGroup inside(List<String> list, {bool caseSensitive = false}) {
    return _opList(list, ConditionOp.inside, caseSensitive);
  }

  ConditionGroup notIn(List<String> list, {bool caseSensitive = false}) {
    return _opList(list, ConditionOp.notIn, caseSensitive);
  }

  ConditionGroup greaterThan(String p, {bool caseSensitive = false, bool withEqual = false}) {
    return _opWithEqual(p, ConditionOp.gt, caseSensitive, withEqual);
  }

  ConditionGroup lessThan(String p, {bool caseSensitive = false, bool withEqual = false}) {
    return _opWithEqual(p, ConditionOp.lt, caseSensitive, withEqual);
  }

  ConditionGroup operator == (String p) => equals(p);
//  ConditionGroup operator != (String p) => notEqual(p); // not overloadable
}

class QueryIntegerProperty extends QueryProperty {
  QueryIntegerProperty({int entityId, int propertyId, int obxType}) : super(entityId, propertyId, obxType);

  ConditionGroup _op(int p, ConditionOp cop) {
    final c = IntegerCondition(cop, type, p, 0);
    return ConditionGroup(entityId, propertyId, c);
  }

  ConditionGroup _opList(List<int> list, ConditionOp cop) {
    final c = IntegerCondition.fromList(cop, type, list);
    return ConditionGroup(entityId, propertyId, c);
  }

  ConditionGroup equals(int p) {
    return _op(p, ConditionOp.eq);
  }

  ConditionGroup notEqual(int p) {
    return _op(p, ConditionOp.notEq);
  }

  ConditionGroup greaterThan(int p) {
    return _op(p, ConditionOp.gt);
  }

  ConditionGroup lessThan(int p) {
    return _op(p, ConditionOp.lt);
  }

  ConditionGroup operator < (int p) => lessThan(p);
  ConditionGroup operator > (int p) => greaterThan(p);

  ConditionGroup inside(List<int> list) {
    return _opList(list, ConditionOp.inside);
  }

  ConditionGroup notInList(List<int> list) {
    return _opList(list, ConditionOp.notIn);
  }

  ConditionGroup notIn(List<int> list) {
    return notInList(list);
  }

  // ConditionGroup operator != (int p) => notEqual(p); // not overloadable
  ConditionGroup operator == (int p) => equals(p);
}

class QueryDoubleProperty extends QueryProperty {

  QueryDoubleProperty({int entityId, int propertyId, int obxType}) : super(entityId, propertyId, obxType);

  ConditionGroup _op(ConditionOp op, double p1, double p2) {
    final c = DoubleCondition(op, type, p1, p2);
    return ConditionGroup(entityId, propertyId, c);
  }

  ConditionGroup between(double p1, double p2) {
    return _op(ConditionOp.between, p1, p2);
  }

  // TODO determine default tolerance: between (target - tolerance, target + tolerance)
  ConditionGroup equals(double p, {double tolerance = 0.01}) {
    final absTolerance = tolerance.abs();
    return between(p - absTolerance, p + absTolerance);
  }

  ConditionGroup greaterThan(double p) {
    return _op(ConditionOp.gt, p, null);
  }

  ConditionGroup lessThan(double p) {
    return _op(ConditionOp.lt, p, null);
  }

  ConditionGroup operator < (double p) => lessThan(p);
  ConditionGroup operator > (double p) => greaterThan(p);
  ConditionGroup operator == (double p) => equals(p);
}

class QueryBooleanProperty extends QueryProperty {
  QueryBooleanProperty({int entityId, int propertyId, int obxType}) : super(entityId, propertyId, obxType);

  ConditionGroup equals(bool p) {
    final c  = IntegerCondition(ConditionOp.eq, type, (p ? 1 : 0));
    return ConditionGroup(entityId, propertyId, c);
  }

  ConditionGroup notEqual(bool p) {
    final c  = IntegerCondition(ConditionOp.notEq, type, (p ? 1 : 0));
    return ConditionGroup(entityId, propertyId, c);
  }

  ConditionGroup operator == (bool p) => equals(p);
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
  all,
  any
}

abstract class Condition<DartType> {
  DartType _value, _value2;
  List<DartType> _list;

  ConditionOp _op;
  int /* OBXPropertyType */ _type;

  Condition(this._op, this._type, this._value, [this._value2 = null]);
  Condition.fromList(this._op, this._type, this._list);

  int _nullness(Pointer<Void> qbPtr, int propertyId, obx_qb_cond_operator_0_dart_t func) {
    return func(qbPtr, propertyId);
  }
  
  int apply(Pointer<Void> cBuilder, int propertyType);
}

class StringCondition extends Condition<String> {
  bool _caseSensitive, _withEqual;

  StringCondition(ConditionOp op, int type, String value, [String value2 = null, bool caseSensitive, bool descending])
      : super(op, type, value, value2) {
    _caseSensitive = caseSensitive;
  }

  StringCondition._fromList(ConditionOp op, int type, List<String> list, bool caseSensitive)
      : super.fromList(op, type, list) {
    _caseSensitive = caseSensitive;
  }

  StringCondition._withEqual(ConditionOp op, int type, String value, bool caseSensitive, bool withEqual)
      : super(op, type, value) {
    _caseSensitive = caseSensitive;
    _withEqual = withEqual;
  }

  int _op1(Pointer<Void> qbPtr, int propertyId, obx_qb_cond_string_op_1_dart_t func) {
    final utf8Str = Utf8.toUtf8(_value);
    try {
      var uint8Str = utf8Str.cast<Uint8>();
      return func(qbPtr, propertyId, uint8Str, _caseSensitive ? 1 : 0);
    } finally {
      utf8Str.free();
    }
  }

  int _inside(Pointer<Void> qbPtr, int propertyId) {
    final func = bindings.obx_qb_string_in;
    final listLength = _list.length;
    final arrayOfUint8Ptrs = Pointer<Pointer<Uint8>>.allocate(count: listLength);
    try {
      for (int i=0; i<_list.length; i++) {
        var uint8Str = Utf8.toUtf8(_list[i]).cast<Uint8>();
        arrayOfUint8Ptrs.elementAt(i).store(uint8Str);
      }
      return func(qbPtr, propertyId, arrayOfUint8Ptrs, listLength, _caseSensitive ? 1 : 0);
    }finally {
      for (int i=0; i<_list.length; i++) {
        var uint8Str = arrayOfUint8Ptrs.elementAt(i).load();
        uint8Str.free(); // I assume the casted Uint8 retains the same Utf8 address
      }
      arrayOfUint8Ptrs.free(); // It probably doesn't release recursively
    }
  }

  int _opWithEqual(Pointer<Void> qbPtr, int propertyId, obx_qb_string_lt_gt_op_dart_t func) {
    final utf8Str = Utf8.toUtf8(_value);
    try {
      var uint8Str = utf8Str.cast<Uint8>();
      return func(qbPtr, propertyId, uint8Str, _caseSensitive ? 1 : 0, _withEqual ? 1 : 0);
    } finally {
      utf8Str.free();
    }
  }
  
  int apply(Pointer<Void> cBuilder, int propertyId) {
    switch (_op) {
      case ConditionOp.eq:
        return _op1(cBuilder, propertyId, bindings.obx_qb_string_equal);
      case ConditionOp.notEq:
        return _op1(
            cBuilder, propertyId, bindings.obx_qb_string_not_equal);
      case ConditionOp.stringContains:
        return _op1(
            cBuilder, propertyId, bindings.obx_qb_string_contains);
      case ConditionOp.stringStarts:
        return _op1(
            cBuilder, propertyId, bindings.obx_qb_string_starts_with);
      case ConditionOp.stringEnds:
        return _op1(
            cBuilder, propertyId, bindings.obx_qb_string_ends_with);
      case ConditionOp.lt:
        return _opWithEqual(
            cBuilder, propertyId, bindings.obx_qb_string_less);
      case ConditionOp.gt:
        return _opWithEqual(
            cBuilder, propertyId, bindings.obx_qb_string_greater);
      case ConditionOp.inside:
        return _inside(cBuilder, propertyId); // bindings.obx_qb_string_in
      default:
        throw Exception("Unsupported operation ${_op.toString()}");
    }
  }
}

class IntegerCondition extends Condition<int> {
  IntegerCondition(ConditionOp op, int type, int value, [int value2 = null])
      : super(op, type, value, value2);

  IntegerCondition.fromList(ConditionOp op, int type, List<int> list)
      : super.fromList(op, type, list);

  int _op1(Pointer<Void> qbPtr, int propertyId, obx_qb_cond_operator_1_dart_t<int> func) {
    return func(qbPtr, propertyId, _value);
  }

  // ideally it should be implemented like this, but this doesn't work, TODO report to google
  /*
  int _opList<P extends NativeType>(Pointer<Void> qbPtr, int propertyId, obx_qb_cond_operator_in_dart_t<P> func) {

    int length = _list.length;
    final listPtr = Pointer<P>.allocate(count: length);
    try {
      for (int i=0; i<length; i++) {
        listPtr.elementAt(i).store(_list[i] as int); // Error: Expected type 'P' to be a valid and instantiated subtype of 'NativeType'. // wtf? Compiler bug?
      }
      return func(qbPtr, propertyId, listPtr, length);
    }finally {
      listPtr.free();
    }
  }
  */

  // TODO replace nasty duplication with implementation above, when fix is in
  int _opList32(Pointer<Void> qbPtr, int propertyId, obx_qb_cond_operator_in_dart_t<Int32> func) {
    int length = _list.length;
    final listPtr = Pointer<Int32>.allocate(count: length);
    try {
      for (int i=0; i<length; i++) {
        listPtr.elementAt(i).store(_list[i]);
      }
      return func(qbPtr, propertyId, listPtr, length);
    }finally {
      listPtr.free();
    }
  }

  // TODO replace duplication with implementation above, when fix is in
  int _opList64(Pointer<Void> qbPtr, int propertyId, obx_qb_cond_operator_in_dart_t<Int64> func) {

    int length = _list.length;
    final listPtr = Pointer<Int64>.allocate(count: length);
    try {
      for (int i=0; i<length; i++) {
        listPtr.elementAt(i).store(_list[i]);
      }
      return func(qbPtr, propertyId, listPtr, length);
    }finally {
      listPtr.free();
    }
  }

  int apply(Pointer<Void> cBuilder, int propertyId) {
    switch (_op) {
      case ConditionOp.eq:
        return _op1(
          cBuilder, propertyId, bindings.obx_qb_int_equal);
      case ConditionOp.notEq:
        return _op1(
          cBuilder, propertyId, bindings.obx_qb_int_not_equal);
      case ConditionOp.gt:
        return _op1(
          cBuilder, propertyId, bindings.obx_qb_int_greater);
      case ConditionOp.lt:
        return _op1(
          cBuilder, propertyId, bindings.obx_qb_int_less);
      case ConditionOp.between:
        return bindings.obx_qb_int_between(
          cBuilder, propertyId, _value, _value2);
      case ConditionOp.inside:
        switch (_type) {
          case OBXPropertyType.Int:
            return _opList32(cBuilder, propertyId, bindings.obx_qb_int32_in);
          case OBXPropertyType.Long:
            return _opList64(cBuilder, propertyId, bindings.obx_qb_int64_in);
          default:
            throw Exception("Unsupported type for IN: ${_type}");
        }
        break;
      case ConditionOp.notIn:
        switch (_type) {
          case OBXPropertyType.Int:
            return _opList32(cBuilder, propertyId, bindings.obx_qb_int32_not_in);
          case OBXPropertyType.Long:
            return _opList64(cBuilder, propertyId, bindings.obx_qb_int64_not_in);
          default:
            throw Exception("Unsupported type for IN: ${_type}");
        }
        break;
      default:
        throw Exception("Unsupported operation ${_op.toString()}");
    }
  }
}

class DoubleCondition extends Condition<double> {
  DoubleCondition(ConditionOp op, int type, double value, double value2)
      : super(op, type, value, value2);

  int _op1(Pointer<Void> qbPtr, int propertyId, obx_qb_cond_operator_1_dart_t<double> func) {
    return func(qbPtr, propertyId, _value);
  }

  int apply(Pointer<Void> cBuilder, int propertyId) {
    switch (_op) {
      case ConditionOp.gt:
        return _op1(
        cBuilder, propertyId, bindings.obx_qb_double_greater);
      case ConditionOp.lt:
        return _op1(cBuilder, propertyId, bindings.obx_qb_double_less);
      case ConditionOp.between:
        return bindings.obx_qb_double_between(
            cBuilder, propertyId, _value, _value2);
      default:
        throw Exception("Unsupported operation ${_op.toString()}");
    }
  }
}

/**
 * The first element of the chain
 * contains the enum representation of
 * the to-be-constructed query builder.
 * This design allows nested chains inside
 * the chain.
 */
class ConditionGroup {
  bool _hasChildren = false;
  int _entityId, _propertyId;
  Condition _condition;
  List<List<ConditionGroup>> _anyGroups; // all
  int _group = 1;

  ConditionGroup(this._entityId, this._propertyId, this._condition);

  // && is not overridable
  ConditionGroup operator&(ConditionGroup rh) => and(rh);

  // || is not overridable
  ConditionGroup operator|(ConditionGroup rh) => or(rh);

  void _initAnyGroupList() {
    _anyGroups ??= <List<ConditionGroup>>[];
  }

  void _initAllGroupList() {
    while (_anyGroups.length < _group) {
      _anyGroups.add(<ConditionGroup>[]);
    }
  }

  ConditionGroup _add(ConditionGroup rh) {
    _hasChildren = true;
    _initAnyGroupList();
    _initAllGroupList();
    _anyGroups[_group - 1].add(rh);
    return this;
  }

  ConditionGroup or(ConditionGroup rh) {
    _group++;
    return _add(rh);
  }

  ConditionGroup and(ConditionGroup rh) {
    return _add(rh);
  }
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
    }finally {
      ptr.free();
    }
  }

  // TODO Document wrap with closure to fake auto close
  void close() {
    checkObx(bindings.obx_query_close(_cQuery));
  }

  T findFirst() {
    final list = find(offset:0, limit:1);
    return (list.length == 0 ? null : list[0]) as T;
  }

  List<int> findIds({int offset=0, int limit=0}) {
    final idArrayPtr = checkObxPtr(bindings.obx_query_find_ids(_cQuery, offset, limit), "find ids");
    try {
      OBX_id_array idArray = idArrayPtr.load();
      return idArray.length == 0 ? List<int>() : idArray.items();
    }finally {
      bindings.obx_id_array_free(idArrayPtr);
    }
  }

  List<T> find({int offset=0, int limit=0}) {
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
}
