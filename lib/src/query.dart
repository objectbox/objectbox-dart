import "dart:ffi";

import "store.dart";
import "bindings/bindings.dart";
import "bindings/constants.dart";
import "bindings/flatbuffers.dart";
import "bindings/helpers.dart";
import "bindings/structs.dart";

/**
 * First a QueryBuilder will be constructed,
 * then when build() is called on the QueryBuilder
 * a Query object will be created.
 */
class QueryProperty {
  int propertyId;
  int schemaId;
  QueryProperty(this.schemaId, this.propertyId);
}

class QueryStringProperty extends QueryProperty {
  QueryStringProperty(int schemaId, int propertyId) : super(schemaId, propertyId);

  static const ConditionType type = ConditionType._string;

  QueryCondition equal(String p, {bool caseSensitive = false}) {
    final c  = Condition<String>(ConditionOp.co_eq, type, p);
    final qc = QueryCondition(schemaId, propertyId, c);

    c.caseSensitive = false;
    qc;
  }

  Condition<String> operator == (String p) {
    equal(p);
  }
}

class QueryIntegerProperty extends QueryProperty {
  QueryIntegerProperty(int schemaId, int propertyId) : super(schemaId, propertyId);

  static const ConditionType type = ConditionType._int64;

  QueryCondition equal(int p) {
    // TODO ideally, let the programmer decide on the resolution via the @Property annot.
    // TODO figure out the current implementation's type
    final c  = Condition<int>(ConditionOp.co_eq, type, p);
    final qc = QueryCondition(schemaId, propertyId, c);

    qc;
  }

  QueryCondition operator == (int p) {
    equal(p);
  }
}

class QueryDoubleProperty extends QueryProperty {
  QueryDoubleProperty(int schemaId, int propertyId) : super(schemaId, propertyId);

  static const ConditionType type = ConditionType._double;

  QueryCondition equal(double p) {
    final c  = Condition<double>(ConditionOp.co_eq, type, p);
    final qc = QueryCondition(schemaId, propertyId, c);

    qc;
  }

  QueryCondition operator == (double p) {
    equal(p);
  }
}

class QueryBooleanProperty extends QueryProperty {
  QueryBooleanProperty(int schemaId, int propertyId) : super(schemaId, propertyId);

  static const ConditionType type = ConditionType._bytes;

  // TODO let the programmer decide on the resolution via the @Property annot.
  QueryCondition equal(bool p) {
    final c  = Condition<int>(ConditionOp.co_eq, type, (p ? 1 : 0));
    final qc = QueryCondition(schemaId, propertyId, c);

    qc;
  }

  QueryCondition
  operator == (bool p) {
    equal(p);
  }
}

// TODO These are not the exact C API System values, shift bits to get the proper C API values
enum OrderFlag {
  /// Reverts the order from ascending (default) to descending.
  DESCENDING, // = 1,

  /// Makes upper case letters (e.g. "Z") be sorted before lower case letters (e.g. "a").
  /// If not specified, the default is case insensitive for ASCII characters.
  CASE_SENSITIVE, // = 2,

  /// For scalars only: changes the comparison to unsigned (default is signed).
  UNSIGNED, // = 4,

  /// null values will be put last.
  /// If not specified, by default null values will be put first.
  NULLS_LAST, // = 8,

  /// null values should be treated equal to zero (scalars only).
  NULLS_ZERO // = 16
}

enum ConditionOp {
  co_null,
  co_not_null,
  co_eq,
  co_not_eq,
  co_string_contains,
  co_string_contain,
  co_string_starts,
  co_string_ends,
  co_gt,
  co_lt,
  co_in,
  co_not_in,
  co_tween,
  co_all,
  co_any
}

// TODO determine what is used for 'bool' (in the current implementation)
enum ConditionType {
  _string,
  _int64,
  _int32,
  _double,
  _bytes,
}

// Property = PropertyType
class Condition<DartType> {
  DartType _value, _value2;

  ConditionOp _op;
  ConditionType _type;

  // TODO add as mixin
  // String specific
  bool caseSensitive; // TODO blow up when used by other types

  Condition(this._op, this._type, this._value, [this._value2 = null]);
}

class QueryCondition {
  int _schemaId, _propertyId;
  Condition _lh_cnf, _rh_cnf;
  List<Condition> _cnf; // all

  String _alias;

  QueryCondition setAlias(String alias) {
    this._alias = alias;
    this; // in case the cascade op is not available
  }

  QueryCondition(this._schemaId, this._propertyId, this._lh_cnf);

  // TODO test: (p > 50) ["alias"] && ...
  QueryCondition operator[](String alias) {
    return setAlias(alias);
  }

  // TODO operator&& ?!
  QueryCondition operator&(QueryCondition rh) {
    all(rh);
  }

  QueryCondition operator|(QueryCondition rh) {
    any(rh);
  }

  // TODO consider renaming to 'or'
  // Construct linked list to navigate between CNF
  QueryCondition any(QueryCondition rh) {
    rh._lh_cnf = this as Condition<dynamic>;
    this._rh_cnf = rh as Condition<dynamic>;
    rh;
  }

  // TODO consider renaming to 'and'
  QueryCondition all(QueryCondition rh) {

    if (_cnf == null) { // TODO use sugar
      _cnf = <QueryCondition>[] as List<Condition<dynamic>>;
    }

    _cnf.add(rh as Condition<dynamic>);

    this;
  }

  QueryBuilder asQueryBuilder(Store store, int schemaId) => QueryBuilder(store, schemaId, this);
}

// TODO run queries
class Query {
  int count() {
    return 0; // TODO replace
  }
}

// TODO construct a tree from the root (Condition)
class QueryBuilder {
  Store _store;
  int _schemaId; // aka model id, entity id
  QueryCondition _condition;

  // TODO use the provided schema id, with the one in the condition
  // TODO to validate the input condition
  QueryBuilder(this._store, this._schemaId, this._condition);

  Query build() {
    Query(); // TODO
  }
}