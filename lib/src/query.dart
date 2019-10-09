import "dart:ffi";

import "box.dart";
import "store.dart";
import "common.dart";
import "bindings/bindings.dart";
import "bindings/constants.dart";
import "bindings/flatbuffers.dart";
import "bindings/helpers.dart";
import "bindings/structs.dart";
import "bindings/signatures.dart";
import "package:ffi/ffi.dart";

// TODO a future or stream(?) should be attachable to the Condition types
// TODO in case there is an error, or some internal message that should be exposed
// TODO do async
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
    final c = Condition<bool>(ConditionOp._null, null, false);
    return new QueryCondition(entityId, propertyId, c);
  }

  QueryCondition notNull() {
    final c = Condition<int>(ConditionOp._not_null, null, 0);
    return new QueryCondition(entityId, propertyId, c);
  }
}

class QueryStringProperty extends QueryProperty {
  QueryStringProperty(int entityId, int propertyId) : super(entityId, propertyId);

  static const ConditionType type = ConditionType._string;

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
    return _op(p, ConditionOp._eq, caseSensitive, false);
  }

  QueryCondition notEqual(String p, {bool caseSensitive = false}) {
    return _op(p, ConditionOp._not_eq, caseSensitive, false);
  }

  QueryCondition endsWith(String p, {bool descending = false}) {
    return _op(p, ConditionOp._string_ends, false, descending);
  }

  QueryCondition startsWith(String p, {bool descending = false}) {
    return _op(p, ConditionOp._string_starts, false, descending);
  }

  QueryCondition contains(String p, {bool caseSensitive = false}) {
    return _op(p, ConditionOp._string_contains, caseSensitive, false);
  }

  // TODO rename to something better
  QueryCondition contain(String p, {bool caseSensitive = false}) {
    return _op(p, ConditionOp._strings_contain, caseSensitive, false);
  }

  QueryCondition inside(List<String> list, {bool caseSensitive = false}) {
    return _opList(list, ConditionOp._in, caseSensitive);
  }

  QueryCondition notIn(List<String> list, {bool caseSensitive = false}) {
    return _opList(list, ConditionOp._not_in, caseSensitive);
  }

  QueryCondition greaterThan(String p, {bool caseSensitive = false, bool withEqual = false}) {
    return _opWithEqual(p, ConditionOp._gt, caseSensitive, withEqual);
  }

  QueryCondition lessThan(String p, {bool caseSensitive = false, bool withEqual = false}) {
    return _opWithEqual(p, ConditionOp._lt, caseSensitive, withEqual);
  }

  QueryCondition operator == (String p) => equals(p);
//  QueryCondition operator != (String p) => notEqual(p); // not overloadable
}

class QueryIntegerProperty extends QueryProperty {
  QueryIntegerProperty(int entityId, int propertyId) : super(entityId, propertyId);

  static const ConditionType type = ConditionType._int64;

  QueryCondition _op(int p, ConditionOp cop) {
    final c = IntegerCondition(ConditionOp._eq, type, p, 0);
    return QueryCondition(entityId, propertyId, c);
  }

  QueryCondition _opList(List<int> list, ConditionOp cop) {
    final c = IntegerCondition.fromList(cop, type, list);
    return QueryCondition(entityId, propertyId, c);
  }

  QueryCondition equals(int p) {
    return _op(p, ConditionOp._eq);
  }

  QueryCondition notEqual(int p) {
    return _op(p, ConditionOp._not_eq);
  }

  QueryCondition greaterThan(int p) {
    return _op(p, ConditionOp._gt);
  }

  QueryCondition lessThan(int p) {
    return _op(p, ConditionOp._lt);
  }

  QueryCondition operator < (int p) => lessThan(p);
  QueryCondition operator > (int p) => greaterThan(p);

  QueryCondition inside(List<int> list) {
    return _opList(list, ConditionOp._in);
  }

  QueryCondition notInList(List<int> list) {
    return _opList(list, ConditionOp._not_in);
  }

  QueryCondition notIn(List<int> list) {
    return notInList(list);
  }

  // QueryCondition operator != (int p) => notEqual(p); // not overloadable
  QueryCondition operator == (int p) => equals(p);
}

class QueryDoubleProperty extends QueryProperty {

  QueryDoubleProperty(int entityId, int propertyId) : super(entityId, propertyId);

  static const ConditionType type = ConditionType._double;

  QueryCondition _op(ConditionOp op, double p1, double p2) {
    final c = DoubleCondition(op, type, p1, p2);
    return QueryCondition(entityId, propertyId, c);
  }

  QueryCondition between(double p1, double p2) {
    return _op(ConditionOp._tween, p1, p2);
  }

  // TODO determine default tolerance: between (target - tolerance, target + tolerance)
  QueryCondition equals(double p, {double tolerance = 0.01}) {
    final absTolerance = tolerance.abs();
    return between(p - absTolerance, p + absTolerance);
  }

  QueryCondition greaterThan(double p) {
    return _op(ConditionOp._gt, p, null);
  }

  QueryCondition lessThan(double p) {
    return _op(ConditionOp._lt, p, null);
  }

  QueryCondition operator < (double p) => lessThan(p);
  QueryCondition operator > (double p) => greaterThan(p);
  QueryCondition operator == (double p) => equals(p);
}

class QueryBooleanProperty extends QueryProperty {
  QueryBooleanProperty(int entityId, int propertyId) : super(entityId, propertyId);

  static const ConditionType type = ConditionType._bytes;

  // TODO let the programmer decide on the resolution via @Property
  QueryCondition equals(bool p) {
    final c  = Condition<int>(ConditionOp._eq, type, (p ? 1 : 0));
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
  _null,
  _not_null,
  _eq,
  _not_eq,
  _string_contains,
  _strings_contain,
  _string_starts,
  _string_ends,
  _gt,
  _lt,
  _in,
  _not_in,
  _tween,
  _all,
  _any
}

// TODO determine what is used for 'bool' (in the current implementation)
enum ConditionType {
  _string,
  _int32,
  _int64,
  _double,
  _bytes,
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

// Construct a tree from the first condition object
class QueryBuilder<T> {
  Box<T> _box;
  Store _store;
  int _entityId; // aka model id, entity id
  QueryCondition _queryCondition;
  Pointer<Void> _cBuilder;

  QueryBuilder(this._box, this._store, this._entityId, this._queryCondition);

  void _throwExceptionIfNecessary() {
    if (bindings.obx_qb_error_code(_cBuilder) != OBXError.OBX_SUCCESS) {
      final msg = Utf8.fromUtf8(bindings.obx_qb_error_message(_cBuilder).cast<Utf8>());
      throw ObjectBoxException("$msg");
    }
  }

  int _create(QueryCondition qc) {
    Condition condition = qc._condition;
    ConditionType type = condition._type;
    ConditionOp   op   = condition._op;
    int propertyId = qc._propertyId;

    // TODO remove debug code
    // print("type: ${type.toString()}, op: ${op.toString()}");

    // do the typecasting here, we can't generalize to an op method
    // due to the differing number of parameters per ConditionType
    try {
      switch (type) {
        case ConditionType._string:
          {
            final stringCondition = qc._condition as StringCondition;
            // why can't we have java-style enums on steroids on dart?
            switch (op) {
              case ConditionOp._eq:
                return stringCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_string_equal);
              case ConditionOp._not_eq:
                return stringCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_string_not_equal);
              case ConditionOp._string_contains:
                return stringCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_string_contains);
              case ConditionOp._strings_contain:
                return stringCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_strings_contain);
              case ConditionOp._string_starts:
                return stringCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_string_starts_with);
              case ConditionOp._string_ends:
                return stringCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_string_ends_with);
              case ConditionOp._lt:
                return stringCondition._opWithEqual(
                    _cBuilder, qc, bindings.obx_qb_string_less);
              case ConditionOp._gt:
                return stringCondition._opWithEqual(
                    _cBuilder, qc, bindings.obx_qb_string_greater);
            }
            break;
          }
        case ConditionType._int64: // current default for int
          {
            final intCondition = qc._condition as IntegerCondition;
            switch (op) {
              case ConditionOp._eq:
                return intCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_int_equal);
              case ConditionOp._not_eq:
                return intCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_int_not_equal);
              case ConditionOp._gt:
                return intCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_int_greater);
              case ConditionOp._lt:
                return intCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_int_less);
            }
            break;
          }
        case ConditionType._double:
          {
            final doubleCondition = qc._condition as DoubleCondition;
            switch (op) {
              case ConditionOp._gt:
                return doubleCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_double_greater);
              case ConditionOp._lt:
                return doubleCondition._op1(
                    _cBuilder, qc, bindings.obx_qb_double_less);
              default:
                break;
            }
            break;
          }
      }

      switch (op) {
        case ConditionOp._null:
          return condition._nullness(_cBuilder, qc, bindings.obx_qb_null);
        case ConditionOp._not_null:
          return condition._nullness(_cBuilder, qc, bindings.obx_qb_not_null);
        case ConditionOp._tween:
          {
            switch (type) {
              case ConditionType._int64: // current default for int
                final c = qc._condition as Condition<int>;
                return bindings.obx_qb_int_between(
                    _cBuilder, propertyId, c._value, c._value2);
              case ConditionType._double:
                final c = qc._condition as Condition<double>;
                return bindings.obx_qb_double_between(
                    _cBuilder, propertyId, c._value, c._value2);
            }
            break;
          }
        case ConditionOp._in:
          {
            switch (type) {
              case ConditionType._int32:
                final c = qc._condition as IntegerCondition;
                return c._opList32(_cBuilder, qc, bindings.obx_qb_int32_in);
              case ConditionType._int64:
                final c = qc._condition as IntegerCondition;
                return c._opList64(_cBuilder, qc, bindings.obx_qb_int64_in);
              case ConditionType._string:
                final c = qc._condition as StringCondition;
                return c._inside(_cBuilder, qc); // bindings.obx_qb_string_in
            }
            break;
          }
        case ConditionOp._not_in:
          {
            switch (type) {
              case ConditionType._int32:
                final c = qc._condition as IntegerCondition;
                return c._opList32(_cBuilder, qc, bindings.obx_qb_int32_not_in);
              case ConditionType._int64:
                final c = qc._condition as IntegerCondition;
                return c._opList64(_cBuilder, qc, bindings.obx_qb_int64_not_in);
            }
            break;
          }
      }
    }finally {
      _throwExceptionIfNecessary();
    }
  }

  int _createGroup(List<int> list, obx_qb_join_op_dart_t func) {
    final size = list.length;
    final intArrayPtr = Pointer<Int32>.allocate(count: size);
    try {
      for(int i = 0; i < size; ++i) {
        intArrayPtr.elementAt(i).store(list[i]);
      }
      return func(_cBuilder, intArrayPtr, size);
    }finally {
      intArrayPtr.free();
      _throwExceptionIfNecessary();
    }
  }

  int _createAllGroup(List<QueryCondition> list) {
    return _createGroup(list.map((qc) => qc._root ? _create(qc) : _parse(qc)).toList(), bindings.obx_qb_all);
  }

  int _createAnyGroup(List<int> list) {
    return _createGroup(list, bindings.obx_qb_any);
  }

  int _parse(QueryCondition qc) {

    assert (qc != null && _cBuilder != null);

    final anyGroup = qc._anyGroups;

    if (anyGroup == null) {
      return _create(qc);
    }

    if (anyGroup.length == 1) {
      if (anyGroup[0].length == 1) {
        return _create(qc);
      }else /* if anyGroup.length == 1 then only apply 'all' */ {
        return _createAllGroup(anyGroup[0]);
      }
    }else /* if anyGroup.length > 1 then apply 'any' */ {
      return _createAnyGroup(anyGroup.map((qcList) => _createAllGroup(qcList)).toList());
    }
  }

  Query build() {
    _cBuilder = bindings.obx_qb_create(_store.ptr, _entityId);

    // TODO pass an empty map to collect properytIds per OrderFlag in `_parse`
    // parse the anyGroup tree in recursion
    _parse(_queryCondition); // ignore the return value

    try {
      return Query<T>._(_box, _cBuilder);
    }finally {
      checkObx(bindings.obx_qb_close(_cBuilder));
    }
  }
}

/*  // Not done yet
    // * = can't test, no support yet, for Double, Long, Boolean, Byte, or Vector... etc.
    * obx_qb_cond_operator_in_dart_t<Int64> obx_qb_int64_in, obx_qb_int64_not_in;
    * obx_qb_cond_operator_in_dart_t<Int32> obx_qb_int32_in, obx_qb_int32_not_in;
    * obx_qb_string_in_dart_t obx_qb_string_in;

    * obx_qb_string_lt_gt_op_dart_t obx_qb_string_greater, obx_qb_string_less;

    obx_qb_bytes_eq_dart_t obx_qb_bytes_equal;
    obx_qb_bytes_lt_gt_dart_t obx_qb_bytes_greater, obx_qb_bytes_less;

    obx_qb_param_alias_dart_t obx_qb_param_alias;

    obx_qb_order_dart_t obx_qb_order;
*/

//////
//////

/** Inspiration
    Modifier and Type	Method	Description
    <TARGET> QueryBuilder<TARGET>	backlink​(RelationInfo<TARGET,?> relationInfo)
    Creates a backlink (reversed link) to another entity, for which you also can describe conditions using the returned builder.
    void	close()
    ** QueryBuilder<T>	eager​(int limit, RelationInfo relationInfo, RelationInfo... more)
    Like eager(RelationInfo, RelationInfo[]), but limits eager loading to the given count.
    ** QueryBuilder<T>	eager​(RelationInfo relationInfo, RelationInfo... more)
    Specifies relations that should be resolved eagerly.
    ** QueryBuilder<T>	filter​(QueryFilter<T> filter) // dart has built-in higher order functions
    Sets a filter that executes on primary query results (returned from the db core) on a Java level.
    <TARGET> QueryBuilder<TARGET>	link​(RelationInfo<?,TARGET> relationInfo)
    Creates a link to another entity, for which you also can describe conditions using the returned builder.
    ** QueryBuilder<T>	order​(Property<T> property)
    Specifies given property to be used for sorting.
    ** QueryBuilder<T>	order​(Property<T> property, int flags)
    Defines the order with which the results are ordered (default: none).
    ** QueryBuilder<T>	orderDesc​(Property<T> property)
    Specifies given property in descending order to be used for sorting.
    ** QueryBuilder<T>	parameterAlias​(java.lang.String alias)
    Assigns the given alias to the previous condition.
    ** QueryBuilder<T>	sort​(java.util.Comparator<T> comparator)
*/