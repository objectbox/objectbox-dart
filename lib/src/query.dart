import "dart:ffi";

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
  int propertyId;
  int entityId;
  QueryProperty(this.entityId, this.propertyId);

  QueryCondition isNull() {
    // the int serves as a placeholder, to initialize the base type
    final c = Condition<int>(ConditionOp._null, null, 0);
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
    final c = StringCondition(cop, type, p, null, caseSensitive ? OrderFlag.CASE_SENSITIVE : 0, descending ? OrderFlag.DESCENDING : 0);
    return QueryCondition(entityId, propertyId, c);
  }

  QueryCondition equal(String p, {bool caseSensitive = false}) {
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

  QueryCondition operator == (String p) => equal(p);
//  QueryCondition operator != (String p) => notEqual(p); // not overloadable
}

class QueryIntegerProperty extends QueryProperty {
  QueryIntegerProperty(int entityId, int propertyId) : super(entityId, propertyId);

  // TODO ideally, let the programmer decide on the resolution via the @Property annot.
  // TODO figure out the current implementation's type
  static const ConditionType type = ConditionType._int64;

  QueryCondition _op(int p, ConditionOp cop) {
    final c = IntegerCondition(ConditionOp._eq, type, p, 0);
    return QueryCondition(entityId, propertyId, c);
  }

  QueryCondition equal(int p) {
    return _op(p, ConditionOp._eq);
  }

  QueryCondition notEqual(int p) {
    return _op(p, ConditionOp._not_eq);
  }

  QueryCondition greater(int p) {
    return _op(p, ConditionOp._gt);
  }

  QueryCondition less(int p) {
    return _op(p, ConditionOp._lt);
  }

  QueryCondition operator == (int p) => equal(p);
//  QueryCondition operator != (int p) => notEqual(p); // not overloadable
}

class QueryDoubleProperty extends QueryProperty {

  QueryDoubleProperty(int entityId, int propertyId) : super(entityId, propertyId);

  static const ConditionType type = ConditionType._double;

  // TODO determine default tolerance: between (target - tolerance, target + tolerance)
  QueryCondition between(double p, [double tolerance = 0.01]) {
    final absTolerance = tolerance.abs();
    final c  = DoubleCondition(ConditionOp._tween, type, p - absTolerance, p + absTolerance);
    return QueryCondition(entityId, propertyId, c);
  }

  QueryCondition equal(double p) {
    return between(p);
  }

  QueryCondition operator == (double p) => equal(p);
}

class QueryBooleanProperty extends QueryProperty {
  QueryBooleanProperty(int entityId, int propertyId) : super(entityId, propertyId);

  static const ConditionType type = ConditionType._bytes;

  // TODO let the programmer decide on the resolution via @Property
  QueryCondition equal(bool p) {
    final c  = Condition<int>(ConditionOp._eq, type, (p ? 1 : 0));
    return QueryCondition(entityId, propertyId, c);
  }

  QueryCondition operator == (bool p) => equal(p);
}

class OrderFlag {
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
  Condition.fromList(this._list); // for in, notIn etc.

  int nullness(Pointer<Void> qbPtr, QueryCondition qc, obx_qb_cond_operator_0_dart_t func) {
    return func(qbPtr, qc._propertyId);
  }
}

class StringCondition extends Condition<String> {
  List<int> orderFlags;
  bool _caseSensitive = false;
  StringCondition(ConditionOp op, ConditionType type, String value, String value2, int caseSensitive, int descending)
      : super(op, type, value, value2) {
    if (caseSensitive > 0) {
      orderFlags ??= <int>[];
      orderFlags.add(caseSensitive);
      _caseSensitive = true;
    }

    if (descending > 0) {
      orderFlags ??= <int>[];
      orderFlags.add(descending);
    }
  }

  int _op1(Pointer<Void> qbPtr, QueryCondition qc, obx_qb_cond_string_op_1_dart_t func) {
    print("val: ${_value}"); // TODO remove debug code
    final utf8Str = Utf8.toUtf8(_value);
    try {
      var utf8Ptr = utf8Str.cast<Uint8>();
      return func(qbPtr, qc._propertyId, utf8Ptr, _caseSensitive ? 1 : 0);
    } finally {
      utf8Str.free();
    }
  }

  // TODO sort by propertyId and put into set to add only once
  get flags => orderFlags;
}

class IntegerCondition extends Condition<int> {
  IntegerCondition(ConditionOp op, ConditionType type, int value, int value2)
      : super(op, type, value, value2);

  int _op1(Pointer<Void> qbPtr, QueryCondition qc, obx_qb_cond_operator_1_dart_t<int> func) {
    return func(qbPtr, qc._propertyId, _value);
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
  List<List<QueryCondition>> _dnf; // all
  int _group = 1;

  QueryCondition(this._entityId, this._propertyId, this._condition);

  // && is not overridable
  QueryCondition operator&(QueryCondition rh) => and(rh);

  // || is not overridable
  QueryCondition operator|(QueryCondition rh) => or(rh);

  // TODO remove later
  void debug() {
    _dnf?.forEach((qc) => qc.map((c) => c._condition).forEach((c) => print("${c._value}")));
    print("dnf size: ${_dnf.length}");
  }

  void _initDnfList(QueryCondition qc) {
    _dnf ??= <List<QueryCondition>>[];
    if (_dnf.length < _group) {
      _dnf.add(<QueryCondition>[]);
    }
    _dnf[_group - 1].add(qc);
  }

  QueryCondition or(QueryCondition rh) {
    rh._root = false;
    if (_dnf == null) {
      _initDnfList(this);
    }
    _group++;
    _initDnfList(rh);
    return this;
  }

  QueryCondition and(QueryCondition rh) {
    rh._root = false;
    if (_dnf == null) {
      _initDnfList(this);
    }
    _initDnfList(rh);
    return this;
  }

  QueryBuilder asQueryBuilder(Store store, int entityId) => QueryBuilder._(store, entityId, this);
}

class Query {
  Pointer<Void> _query;

  // package private ctor
  Query._(Pointer<Void> qb) {
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

  // TODO does dart have a dtor/finalizer?
  void close() {
    checkObx(bindings.obx_query_close(_query));
    // TODO _query.free(); === double release ?
  }
}

// Construct a tree from the first condition object
class QueryBuilder {
  Store _store;
  int _entityId; // aka model id, entity id
  QueryCondition _queryCondition;
  Pointer<Void> _queryBuilderPtr;

  // package private ctor
  QueryBuilder._(this._store, this._entityId, this._queryCondition);

  void _throwExceptionIfNecessary() {
    if (bindings.obx_qb_error_code(_queryBuilderPtr) != OBXError.OBX_SUCCESS) {
      final msg = Utf8.fromUtf8(bindings.obx_qb_error_message(_queryBuilderPtr).cast<Utf8>());
      throw ObjectBoxException("$msg");
    }
  }

  int _create(QueryCondition qc) {
    Condition condition = qc._condition;
    ConditionType type = condition._type;
    ConditionOp   op   = condition._op;
    int propertyId = qc._propertyId;

    // TODO remove debug code
    print("type: ${type.toString()}, op: ${op.toString()}");

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
                    _queryBuilderPtr, qc, bindings.obx_qb_string_equal);
              case ConditionOp._not_eq:
                return stringCondition._op1(
                    _queryBuilderPtr, qc, bindings.obx_qb_string_not_equal);
              case ConditionOp._string_contains:
                return stringCondition._op1(
                    _queryBuilderPtr, qc, bindings.obx_qb_string_contains);
              case ConditionOp._strings_contain:
                return stringCondition._op1(
                    _queryBuilderPtr, qc, bindings.obx_qb_strings_contain);
              case ConditionOp._string_starts:
                return stringCondition._op1(
                    _queryBuilderPtr, qc, bindings.obx_qb_string_starts_with);
              case ConditionOp._string_ends:
                return stringCondition._op1(
                    _queryBuilderPtr, qc, bindings.obx_qb_string_ends_with);
            }
            break;
          }
        case ConditionType._int64: // current default for int
          {
            final intCondition = qc._condition as IntegerCondition;
            switch (op) {
              case ConditionOp._eq:
                return intCondition._op1(
                    _queryBuilderPtr, qc, bindings.obx_qb_int_equal);
              case ConditionOp._not_eq:
                return intCondition._op1(
                    _queryBuilderPtr, qc, bindings.obx_qb_int_not_equal);
              case ConditionOp._gt:
                return intCondition._op1(
                    _queryBuilderPtr, qc, bindings.obx_qb_int_greater);
              case ConditionOp._lt:
                return intCondition._op1(
                    _queryBuilderPtr, qc, bindings.obx_qb_int_less);
            }
            break;
          }
        case ConditionType._double:
          {
            final doubleCondition = qc._condition as DoubleCondition;
            switch (op) {
              case ConditionOp._gt:
                return doubleCondition._op1(
                    _queryBuilderPtr, qc, bindings.obx_qb_double_greater);
              case ConditionOp._lt:
                return doubleCondition._op1(
                    _queryBuilderPtr, qc, bindings.obx_qb_double_less);
              default:
                break;
            }
            break;
          }
      }

      switch (op) {
        case ConditionOp._null:
          return condition.nullness(_queryBuilderPtr, qc, bindings.obx_qb_null);
        case ConditionOp._not_null:
          return condition.nullness(_queryBuilderPtr, qc, bindings.obx_qb_not_null);
        case ConditionOp._tween:
          {
            switch (type) {
              case ConditionType._int64: // current default for int
                final c = qc._condition as Condition<int>;
                return bindings.obx_qb_int_between(
                    _queryBuilderPtr, propertyId, c._value, c._value2);
              case ConditionType._double:
                final c = qc._condition as Condition<double>;
                return bindings.obx_qb_double_between(
                    _queryBuilderPtr, propertyId, c._value, c._value2);
            }
            break;
          }
          /*
        case ConditionOp._in:
          switch (type) {
            case ConditionType._int32:
              Pointer<T>.allocate(count: )
              return bindings.obx_qb_int32_in(_queryBuilderPtr, propertyId, );
            case ConditionType._int64:
           */

            /**
            obx_qb_cond_operator_in_dart_t<Int64> obx_qb_int64_in, obx_qb_int64_not_in;
            obx_qb_cond_operator_in_dart_t<Int32> obx_qb_int32_in, obx_qb_int32_not_in;

            typedef obx_qb_cond_operator_in_native_t<P> = Int32 Function(Pointer<Void> builder, Uint32 property_id, Pointer<P> values, Uint64 count);
            typedef obx_qb_cond_operator_in_dart_t<P>   = int Function(Pointer<Void> builder, int property_id, Pointer<P> values, int count);
            */

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
      return func(_queryBuilderPtr, intArrayPtr, size);
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

    assert (qc != null && _queryBuilderPtr != null);

    final dnf = qc._dnf;

    if (dnf == null) {
      return _create(qc);
    }

    if (dnf.length == 1) {
      if (dnf[0].length == 1) {
        return _create(qc);
      }else /* if dnf.length == 1 then only apply 'all' */ {
        return _createAllGroup(dnf[0]);
      }
    }else /* if dnf.length > 1 then apply 'any' */ {
      return _createAnyGroup(dnf.map((qcList) => _createAllGroup(qcList)).toList());
    }
  }

  Query build() {
    _queryBuilderPtr = bindings.obx_qb_create(_store.ptr, _entityId);

    // TODO pass an empty map to collect properytIds per OrderFlag in `_parse`
    // parse the dnf tree in recursion
    _parse(_queryCondition); // ignore the return value

    try {
      return Query._(_queryBuilderPtr);
    }finally {
      checkObx(bindings.obx_qb_close(_queryBuilderPtr));
    }
  }
}

/**
 *
    obx_qb_cond_operator_in_dart_t<Int64> obx_qb_int64_in, obx_qb_int64_not_in;
    obx_qb_cond_operator_in_dart_t<Int32> obx_qb_int32_in, obx_qb_int32_not_in;

    obx_qb_string_lt_gt_op_dart_t obx_qb_string_greater, obx_qb_string_less;
    obx_qb_string_in_dart_t obx_qb_string_in;

    obx_qb_bytes_eq_dart_t obx_qb_bytes_equal;
    obx_qb_bytes_lt_gt_dart_t obx_qb_bytes_greater, obx_qb_bytes_less;

    obx_qb_param_alias_dart_t obx_qb_param_alias;

    obx_qb_order_dart_t obx_qb_order;
*/

//////
//////

/**
    Modifier and Type	Method	Description
    And AND changes how conditions are combined using a following OR.
    <TARGET> QueryBuilder<TARGET>	backlink​(RelationInfo<TARGET,?> relationInfo)
    Creates a backlink (reversed link) to another entity, for which you also can describe conditions using the returned builder.
    ** QueryBuilder<T>	between​(Property<T> property, double value1, double value2)
    ** QueryBuilder<T>	between​(Property<T> property, long value1, long value2)
    ** QueryBuilder<T>	between​(Property<T> property, java.util.Date value1, java.util.Date value2)
    Builds the query and closes this QueryBuilder.
    void	close()
    ** QueryBuilder<T>	contains​(Property<T> property, java.lang.String value)
    ** QueryBuilder<T>	contains​(Property<T> property, java.lang.String value, QueryBuilder.StringOrder order)
    ** QueryBuilder<T>	eager​(int limit, RelationInfo relationInfo, RelationInfo... more)
    Like eager(RelationInfo, RelationInfo[]), but limits eager loading to the given count.
    ** QueryBuilder<T>	eager​(RelationInfo relationInfo, RelationInfo... more)
    Specifies relations that should be resolved eagerly.
    ** QueryBuilder<T>	endsWith​(Property<T> property, java.lang.String value)
    ** QueryBuilder<T>	endsWith​(Property<T> property, java.lang.String value, QueryBuilder.StringOrder order)
    ** QueryBuilder<T>	equal​(Property<T> property, boolean value)
    ** QueryBuilder<T>	equal​(Property<T> property, byte[] value)
    ** QueryBuilder<T>	equal​(Property<T> property, double value, double tolerance)
    Floating point equality is non-trivial; this is just a convenience for between(Property, double, double) with parameters(property, value - tolerance, value + tolerance).
    ** QueryBuilder<T>	equal​(Property<T> property, long value)
    ** QueryBuilder<T>	equal​(Property<T> property, java.lang.String value)
    ** QueryBuilder<T>	equal​(Property<T> property, java.lang.String value, QueryBuilder.StringOrder order)
    ** QueryBuilder<T>	equal​(Property<T> property, java.util.Date value)
    ** QueryBuilder<T>	filter​(QueryFilter<T> filter)
    Sets a filter that executes on primary query results (returned from the db core) on a Java level.
    protected void	finalize()
    ** QueryBuilder<T>	greater​(Property<T> property, byte[] value)
    ** QueryBuilder<T>	greater​(Property<T> property, double value)
    ** QueryBuilder<T>	greater​(Property<T> property, long value)
    ** QueryBuilder<T>	greater​(Property<T> property, java.lang.String value)
    ** QueryBuilder<T>	greater​(Property<T> property, java.lang.String value, QueryBuilder.StringOrder order)
    ** QueryBuilder<T>	greater​(Property<T> property, java.util.Date value)
    ** QueryBuilder<T>	in​(Property<T> property, int[] values)
    ** QueryBuilder<T>	in​(Property<T> property, long[] values)
    ** QueryBuilder<T>	in​(Property<T> property, java.lang.String[] values)
    ** QueryBuilder<T>	in​(Property<T> property, java.lang.String[] values, QueryBuilder.StringOrder order)
    ** QueryBuilder<T>	isNull​(Property<T> property)
    ** QueryBuilder<T>	less​(Property<T> property, byte[] value)
    ** QueryBuilder<T>	less​(Property<T> property, double value)
    ** QueryBuilder<T>	less​(Property<T> property, long value)
    ** QueryBuilder<T>	less​(Property<T> property, java.lang.String value)
    ** QueryBuilder<T>	less​(Property<T> property, java.lang.String value, QueryBuilder.StringOrder order)
    ** QueryBuilder<T>	less​(Property<T> property, java.util.Date value)
    <TARGET> QueryBuilder<TARGET>	link​(RelationInfo<?,TARGET> relationInfo)
    Creates a link to another entity, for which you also can describe conditions using the returned builder.
    ** QueryBuilder<T>	notEqual​(Property<T> property, boolean value)
    ** QueryBuilder<T>	notEqual​(Property<T> property, long value)
    ** QueryBuilder<T>	notEqual​(Property<T> property, java.lang.String value)
    ** QueryBuilder<T>	notEqual​(Property<T> property, java.lang.String value, QueryBuilder.StringOrder order)
    ** QueryBuilder<T>	notEqual​(Property<T> property, java.util.Date value)
    ** QueryBuilder<T>	notIn​(Property<T> property, int[] values)
    ** QueryBuilder<T>	notIn​(Property<T> property, long[] values)
    ** QueryBuilder<T>	notNull​(Property<T> property)
    Combines the previous condition with the following condition with a logical OR.
    ** QueryBuilder<T>	order​(Property<T> property)
    Specifies given property to be used for sorting.
    ** QueryBuilder<T>	order​(Property<T> property, int flags)
    Defines the order with which the results are ordered (default: none).
    ** QueryBuilder<T>	orderDesc​(Property<T> property)
    Specifies given property in descending order to be used for sorting.
    ** QueryBuilder<T>	parameterAlias​(java.lang.String alias)
    Assigns the given alias to the previous condition.
    ** QueryBuilder<T>	sort​(java.util.Comparator<T> comparator)
    ** QueryBuilder<T>	startsWith​(Property<T> property, java.lang.String value)
    ** QueryBuilder<T>	startsWith​(Property<T> property, java.lang.String value, QueryBuilder.StringOrder order)
*/