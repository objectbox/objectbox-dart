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
    final c = Condition<String>(ConditionOp.co_eq, type, p);
    c.caseSensitive = false;
    return QueryCondition(schemaId, propertyId, c);
  }

  QueryCondition operator == (String p) => equal(p);
}

class QueryIntegerProperty extends QueryProperty {
  QueryIntegerProperty(int schemaId, int propertyId) : super(schemaId, propertyId);

  static const ConditionType type = ConditionType._int64;

  QueryCondition equal(int p) {
    // TODO ideally, let the programmer decide on the resolution via the @Property annot.
    // TODO figure out the current implementation's type
    final c  = Condition<int>(ConditionOp.co_eq, type, p);
    return QueryCondition(schemaId, propertyId, c);
  }

  QueryCondition operator == (int p) => equal(p);
}

class QueryDoubleProperty extends QueryProperty {
  QueryDoubleProperty(int schemaId, int propertyId) : super(schemaId, propertyId);

  static const ConditionType type = ConditionType._double;

  QueryCondition equal(double p) {
    final c  = Condition<double>(ConditionOp.co_eq, type, p);
    return QueryCondition(schemaId, propertyId, c);
  }

  QueryCondition operator == (double p) => equal(p);
}

class QueryBooleanProperty extends QueryProperty {
  QueryBooleanProperty(int schemaId, int propertyId) : super(schemaId, propertyId);

  static const ConditionType type = ConditionType._bytes;

  // TODO let the programmer decide on the resolution via the @Property annot.
  QueryCondition equal(bool p) {
    final c  = Condition<int>(ConditionOp.co_eq, type, (p ? 1 : 0));
    return QueryCondition(schemaId, propertyId, c);
  }

  QueryCondition operator == (bool p) => equal(p);
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

class Condition<DartType> {
  DartType _value, _value2;

  ConditionOp _op;
  ConditionType _type;

  bool caseSensitive; // TODO blow up when used by other types

  Condition(this._op, this._type, this._value, [this._value2 = null]);
}

class QueryCondition {
  int _schemaId, _propertyId;
  QueryCondition _lh_cnf, _rh_cnf;
  Condition<dynamic> condition;
  List<QueryCondition> _cnf; // all

  String _alias;

  QueryCondition setAlias(String alias) {
    this._alias = alias;
    return this; // in case the cascade op is not available
  }

  QueryCondition(this._schemaId, this._propertyId, this.condition);

  // TODO test: (p > 50) ["alias"] && ...
  QueryCondition operator[](String alias) => setAlias(alias);

  QueryCondition operator&(QueryCondition rh) => and(rh);

  QueryCondition operator|(QueryCondition rh) => or(rh);

  // Construct linked list to navigate between CNF
  QueryCondition or(QueryCondition rh) {
    rh._lh_cnf = this;
    this._rh_cnf = rh;
    return rh;
  }

  QueryCondition and(QueryCondition rh) {
    _cnf ??= <QueryCondition>[];
    _cnf.add(rh);

    return this;
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
    return Query(); // TODO
  }
}