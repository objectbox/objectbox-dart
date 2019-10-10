library query;

import "dart:ffi";

import "../box.dart";
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
  int propertyId; // why hide this if it's exposed in the entity definition, // TODO final / const?
  int entityId;
  QueryProperty(this.entityId, this.propertyId);

  QueryCondition isNull() {
    // the bool serves as a dummy type, to initialize the base type
    final c = Condition<bool>(ConditionOp.nil, null, false);
    return new QueryCondition(entityId, propertyId, c);
  }

  QueryCondition notNull() {
    final c = Condition<int>(ConditionOp.not_nil, null, 0);
    return new QueryCondition(entityId, propertyId, c);
  }
}

class QueryStringProperty extends QueryProperty {
  QueryStringProperty(int entityId, int propertyId) : super(entityId, propertyId);

  static const ConditionType type = ConditionType.string;

  QueryCondition _op(String p, ConditionOp cop, bool caseSensitive, bool descending) {
    final c = StringCondition(cop, type, p, null, caseSensitive ? OBXOrderFlag.CASE_SENSITIVE : 0, descending ? OBXOrderFlag.DESCENDING : 0);
    return QueryCondition(entityId, propertyId, c);
  }

  QueryCondition _opWithEqual(String p, ConditionOp cop, bool caseSensitive, bool withEqual) {
    final c = StringCondition._withEqual(cop, type, p, caseSensitive ? OBXOrderFlag.CASE_SENSITIVE : 0, withEqual);
    return QueryCondition(entityId, propertyId, c);
  }

  QueryCondition _opList(List<String> list, ConditionOp cop, bool caseSensitive) {
    final c = StringCondition._fromList(cop, type, list, caseSensitive ? OBXOrderFlag.CASE_SENSITIVE : 0);
    return QueryCondition(entityId, propertyId, c);
  }

  QueryCondition equals(String p, {bool caseSensitive = false}) {
    return _op(p, ConditionOp.eq, caseSensitive, false);
  }

  QueryCondition notEqual(String p, {bool caseSensitive = false}) {
    return _op(p, ConditionOp.not_eq, caseSensitive, false);
  }

  QueryCondition endsWith(String p, {bool descending = false}) {
    return _op(p, ConditionOp.string_ends, false, descending);
  }

  QueryCondition startsWith(String p, {bool descending = false}) {
    return _op(p, ConditionOp.string_starts, false, descending);
  }

  QueryCondition contains(String p, {bool caseSensitive = false}) {
    return _op(p, ConditionOp.string_contains, caseSensitive, false);
  }

  QueryCondition inside(List<String> list, {bool caseSensitive = false}) {
    return _opList(list, ConditionOp.inside, caseSensitive);
  }

  QueryCondition notIn(List<String> list, {bool caseSensitive = false}) {
    return _opList(list, ConditionOp.not_in, caseSensitive);
  }

  QueryCondition greaterThan(String p, {bool caseSensitive = false, bool withEqual = false}) {
    return _opWithEqual(p, ConditionOp.gt, caseSensitive, withEqual);
  }

  QueryCondition lessThan(String p, {bool caseSensitive = false, bool withEqual = false}) {
    return _opWithEqual(p, ConditionOp.lt, caseSensitive, withEqual);
  }

  QueryCondition operator == (String p) => equals(p);
//  QueryCondition operator != (String p) => notEqual(p); // not overloadable
}

class QueryIntegerProperty extends QueryProperty {
  QueryIntegerProperty(int entityId, int propertyId) : super(entityId, propertyId);

  static const ConditionType type = ConditionType.int64;

  QueryCondition _op(int p, ConditionOp cop) {
    final c = IntegerCondition(cop, type, p, 0);
    return QueryCondition(entityId, propertyId, c);
  }

  QueryCondition _opList(List<int> list, ConditionOp cop) {
    final c = IntegerCondition.fromList(cop, type, list);
    return QueryCondition(entityId, propertyId, c);
  }

  QueryCondition equals(int p) {
    return _op(p, ConditionOp.eq);
  }

  QueryCondition notEqual(int p) {
    return _op(p, ConditionOp.not_eq);
  }

  QueryCondition greaterThan(int p) {
    return _op(p, ConditionOp.gt);
  }

  QueryCondition lessThan(int p) {
    return _op(p, ConditionOp.lt);
  }

  QueryCondition operator < (int p) => lessThan(p);
  QueryCondition operator > (int p) => greaterThan(p);

  QueryCondition inside(List<int> list) {
    return _opList(list, ConditionOp.inside);
  }

  QueryCondition notInList(List<int> list) {
    return _opList(list, ConditionOp.not_in);
  }

  QueryCondition notIn(List<int> list) {
    return notInList(list);
  }

  // QueryCondition operator != (int p) => notEqual(p); // not overloadable
  QueryCondition operator == (int p) => equals(p);
}

class QueryDoubleProperty extends QueryProperty {

  QueryDoubleProperty(int entityId, int propertyId) : super(entityId, propertyId);

  static const ConditionType type = ConditionType.float64;

  QueryCondition _op(ConditionOp op, double p1, double p2) {
    final c = DoubleCondition(op, type, p1, p2);
    return QueryCondition(entityId, propertyId, c);
  }

  QueryCondition between(double p1, double p2) {
    return _op(ConditionOp.tween, p1, p2);
  }

  // TODO determine default tolerance: between (target - tolerance, target + tolerance)
  QueryCondition equals(double p, {double tolerance = 0.01}) {
    final absTolerance = tolerance.abs();
    return between(p - absTolerance, p + absTolerance);
  }

  QueryCondition greaterThan(double p) {
    return _op(ConditionOp.gt, p, null);
  }

  QueryCondition lessThan(double p) {
    return _op(ConditionOp.lt, p, null);
  }

  QueryCondition operator < (double p) => lessThan(p);
  QueryCondition operator > (double p) => greaterThan(p);
  QueryCondition operator == (double p) => equals(p);
}

class QueryBooleanProperty extends QueryProperty {
  QueryBooleanProperty(int entityId, int propertyId) : super(entityId, propertyId);

  static const ConditionType type = ConditionType.bytes;

  // TODO let the programmer decide on the resolution via @Property
  QueryCondition equals(bool p) {
    final c  = Condition<int>(ConditionOp.eq, type, (p ? 1 : 0));
    return QueryCondition(entityId, propertyId, c);
  }

  QueryCondition operator == (bool p) => equals(p);
}

class OBXOrderFlag {
  /// Reverts the order from ascending (default) to descending.
  static final DESCENDING = 1;

  /// Makes upper case letters (e.g. "Z") be sorted before lower case letters (e.g. "a").
  /// If not specified, the default is case insensitive for ASCII characters.
  static final CASE_SENSITIVE = 2;

  /// For scalars only: changes the comparison to unsigned (default is signed).
  static final UNSIGNED = 4;

  /// null values will be put last.
  /// If not specified, by default null values will be put first.
  static final NULLS_LAST = 8;

  /// null values should be treated equal to zero (scalars only).
  static final NULLS_ZERO = 16;
}

enum ConditionOp {
  nil,
  not_nil,
  eq,
  not_eq,
  string_contains,
  string_starts,
  string_ends,
  gt,
  lt,
  inside,
  not_in,
  tween,
  all,
  any
}

// TODO determine what is used for 'bool' (in the current implementation)
enum ConditionType {
  string,
  int32,
  int64,
  float64,
  bytes,
}

class Condition<DartType> {
  DartType _value, _value2;
  List<DartType> _list;

  ConditionOp _op;
  ConditionType _type;

  Condition(this._op, this._type, this._value, [this._value2 = null]);
  Condition.fromList(this._op, this._type, this._list);

  int _nullness(Pointer<Void> qbPtr, QueryCondition qc, obx_qb_cond_operator_0_dart_t func) {
    return func(qbPtr, qc._propertyId);
  }
}

class StringCondition extends Condition<String> {
  List<int> orderFlags;
  bool _caseSensitive = false, _withEqual = false;

  StringCondition(ConditionOp op, ConditionType type, String value, String value2, int caseSensitive, int descending)
      : super(op, type, value, value2) {
    _initCaseSensitivity(caseSensitive);

    if (descending > 0) {
      orderFlags ??= <int>[];
      orderFlags.add(descending);
    }
  }

  StringCondition._fromList(ConditionOp op, ConditionType type, List<String> list, int caseSensitive)
      : super.fromList(op, type, list) {
    _initCaseSensitivity(caseSensitive);
  }

  StringCondition._withEqual(ConditionOp op, ConditionType type, String value, int caseSensitive, bool withEqual)
      : super(op, type, value) {
    _initCaseSensitivity(caseSensitive);
    _withEqual = withEqual;
  }

  int _op1(Pointer<Void> qbPtr, QueryCondition qc, obx_qb_cond_string_op_1_dart_t func) {
    final utf8Str = Utf8.toUtf8(_value);
    try {
      var uint8Str = utf8Str.cast<Uint8>();
      return func(qbPtr, qc._propertyId, uint8Str, _caseSensitive ? 1 : 0);
    } finally {
      utf8Str.free();
    }
  }

  int _inside(Pointer<Void> qbPtr, QueryCondition qc) {
    final func = bindings.obx_qb_string_in;
    final listLength = _list.length;
    final arrayOfUint8Ptrs = Pointer<Pointer<Uint8>>.allocate(count: listLength);
    try {
      for (int i=0; i<_list.length; i++) {
        var uint8Str = Utf8.toUtf8(_list[i]).cast<Uint8>();
        arrayOfUint8Ptrs.elementAt(i).store(uint8Str);
      }
      return func(qbPtr, qc._propertyId, arrayOfUint8Ptrs, listLength, _caseSensitive ? 1 : 0);
    }finally {
      for (int i=0; i<_list.length; i++) {
        var uint8Str = arrayOfUint8Ptrs.elementAt(i).load();
        uint8Str.free(); // I assume the casted Uint8 retains the same Utf8 address
      }
      arrayOfUint8Ptrs.free(); // It probably doesn't release recursively
    }
  }

  int _opWithEqual(Pointer<Void> qbPtr, QueryCondition qc, obx_qb_string_lt_gt_op_dart_t func) {
    final utf8Str = Utf8.toUtf8(_value);
    try {
      var uint8Str = utf8Str.cast<Uint8>();
      return func(qbPtr, qc._propertyId, uint8Str, _caseSensitive ? 1 : 0, _withEqual ? 1 : 0);
    } finally {
      utf8Str.free();
    }
  }

  void _initCaseSensitivity(int caseSensitive) {
    if (caseSensitive > 0) {
      orderFlags ??= <int>[];
      orderFlags.add(caseSensitive);
      _caseSensitive = true;
    }
  }

  // TODO sort by propertyId and put into set to add only once, use Map<orderFlag, Set<propertyId>>
  get flags => orderFlags;
}

class IntegerCondition extends Condition<int> {
  IntegerCondition(ConditionOp op, ConditionType type, int value, int value2)
      : super(op, type, value, value2);

  IntegerCondition.fromList(ConditionOp op, ConditionType type, List<int> list)
      : super.fromList(op, type, list);

  int _op1(Pointer<Void> qbPtr, QueryCondition qc, obx_qb_cond_operator_1_dart_t<int> func) {
    return func(qbPtr, qc._propertyId, _value);
  }

  // ideally it should be implemented like this, but this doesn't work, TODO report to google
  /*
  int _opList<P extends NativeType>(Pointer<Void> qbPtr, QueryCondition qc, obx_qb_cond_operator_in_dart_t<P> func) {
    int propertyId = qc._propertyId;
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
  int _opList32(Pointer<Void> qbPtr, QueryCondition qc, obx_qb_cond_operator_in_dart_t<Int32> func) {
    int propertyId = qc._propertyId;
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
  int _opList64(Pointer<Void> qbPtr, QueryCondition qc, obx_qb_cond_operator_in_dart_t<Int64> func) {
    int propertyId = qc._propertyId;
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

}

class DoubleCondition extends Condition<double> {
  DoubleCondition(ConditionOp op, ConditionType type, double value, double value2)
      : super(op, type, value, value2);

  int _op1(Pointer<Void> qbPtr, QueryCondition qc, obx_qb_cond_operator_1_dart_t<double> func) {
    return func(qbPtr, qc._propertyId, _value);
  }
}

/**
 * The first element of the chain
 * contains the enum representation of
 * the to-be-constructed query builder.
 * This design allows nested chains inside
 * the chain.
 */
class QueryCondition {
  bool _root = true;
  int _entityId, _propertyId;
  Condition _condition;
  List<List<QueryCondition>> _anyGroups; // all
  int _group = 1;

  QueryCondition(this._entityId, this._propertyId, this._condition);

  // && is not overridable
  QueryCondition operator&(QueryCondition rh) => and(rh);

  // || is not overridable
  QueryCondition operator|(QueryCondition rh) => or(rh);

  // TODO remove later
  void debug() {
    _anyGroups?.forEach((qc) => qc.map((c) => c._condition).forEach((c) => print("${c._value}")));
    print("anyGroup size: ${_anyGroups.length}");
  }

  void _initAnyGroupList(QueryCondition qc) {
    _anyGroups ??= <List<QueryCondition>>[];
    if (_anyGroups.length < _group) {
      _anyGroups.add(<QueryCondition>[]);
    }
    _anyGroups[_group - 1].add(qc);
  }

  QueryCondition or(QueryCondition rh) {
    rh._root = false;
    if (_anyGroups == null) {
      _initAnyGroupList(this);
    }
    _group++;
    _initAnyGroupList(rh);
    return this;
  }

  QueryCondition and(QueryCondition rh) {
    rh._root = false;
    if (_anyGroups == null) {
      _initAnyGroupList(this);
    }
    _initAnyGroupList(rh);
    return this;
  }
}

class Query<T> {
  Pointer<Void> _query;
  Box<T> _box;

  // package private ctor
  Query._(Box<T> box, Pointer<Void> qb) {
    _box = box;
    _query = checkObxPtr(bindings.obx_query_create(qb), "create query", true);
  }

  int count() {
    final ptr = Pointer<Uint64>.allocate(count: 1);
    try {
      checkObx(bindings.obx_query_count(_query, ptr));
      return ptr.load();
    }finally {
      ptr.free();
    }
  }

  // TODO does dart have a dtor/finalizer?j
  void close() {
    checkObx(bindings.obx_query_close(_query));
  }

  // TODO reimplement the same marshalling as in Box.getMany???
  T findFirst() {
    final list = findIds(offset:0, limit:1);
    return (list == null ? null : _box.get(list.first)) as T;
  }

  List<int> findIds({int offset=0, int limit=0}) {
    final structPtr = checkObxPtr(bindings.obx_query_find_ids(_query, offset, limit), "find ids");
    try {
      final idArray = IDArray.fromAddress(structPtr.address);
      return idArray.ids.length == 0 ? null : idArray.ids;
    }finally {
      bindings.obx_id_array_free(structPtr);
    }
  }

  List<T> find({int offset=0, int limit=0}) {
    final list = findIds(offset:offset, limit:limit);
    return list == null ? null : _box.getMany(list);
  }
}
