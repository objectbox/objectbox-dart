import "package:test/test.dart";
import "package:objectbox/objectbox.dart";
import "entity.dart";
import 'test_env.dart';

void main() {
  TestEnv<TestEntityProperty> env;
  Box box;

  setUp(() {
    env = TestEnv(TestEntityProperty_OBXDefs, "query_property");
    box = env.box;
  });

  final integerList = [0, 0, 1, 1, 2, 3, 4, 5].map((i) => TestEntityProperty.initIntegers(true, 1+i, 2+i, 3+i, 4+i, 5+i)).toList();
  final stringList  = ["string", "another", "string", "1withSuffix", "2withSuffix", "1withSuffix"].map((s) => TestEntityProperty.initString(s)).toList();
  final floatList  = [0, 0.0, 0.1, 0.2, 0.1].map((f) => TestEntityProperty.initFloats(0.1+f, 0.2+f)).toList();

  final tBool = TestEntityProperty_.tBool;
  final tLong = TestEntityProperty_.tLong;
  final tInt = TestEntityProperty_.tInt;
  final tShort = TestEntityProperty_.tShort;
  final tChar = TestEntityProperty_.tChar;
  final tByte = TestEntityProperty_.tByte;
  final tIntegers = [ tBool, tLong, tInt, tShort, tChar, tByte ];

  final tFloat = TestEntityProperty_.tFloat;
  final tDouble = TestEntityProperty_.tDouble;
  final tFloats = [ tFloat, tDouble ];

  final tString = TestEntityProperty_.tString;

  test(".count (basic query)", () {
    box.putMany(integerList);
    box.putMany(stringList);
    box.putMany(floatList);

    tIntegers.forEach((i) {
      if (i is QueryBooleanProperty) { return; }
      final queryInt = box.query((i as QueryIntegerProperty).greaterThan(0)).build();
      expect(queryInt.count(), 8);
      queryInt.close();
    });

    tFloats.forEach((f) {
      final queryFloat = box.query((f as QueryDoubleProperty).lessThan(1.0)).build();
      expect(queryFloat.count(), 5);
      queryFloat.close();
    });

    final queryString = box.query(tString.contains('t')).build();
    expect(queryString.count(), 6);
    queryString.close();
  });

  test(".distinct, .count, .close property query", () {
    box.putMany(integerList);
    box.putMany(stringList);
    box.putMany(floatList);

    // int
    final query = box.query((tLong < 2) as Condition).build();

    final queryInt = query.property(tLong);
    expect(queryInt.count(), 4);
    queryInt.close();

    // TODO NPE on queryInt (no errors thrown), can't reuse queryInt, turn on when fixed (dart 2.6?)
//    final tLongDistinctCount = queryInt..distinct(true)..count();
//    expect(2, tLongDistinctCount);

    final queryInt2 = query.property(tLong);
    expect(queryInt2..distinct(true)..count(), 2);
    queryInt2.close();

    query.close();
  });

  test("query.property(E_.field) property query, type inference", () {
    box.putMany(integerList);
    box.putMany(stringList);
    box.putMany(floatList);

    final query = box.query((tLong < 2) as Condition).build();

    tIntegers.forEach((i) {
      final qp = query.property(i);
      expect(qp is IntegerPropertyQuery, true);
      qp.close();
    });

    tFloats.forEach((f) {
      final qp = query.property(f);
      expect(qp is DoublePropertyQuery, true);
      qp.close();
    });

    final qp = query.property(tString);
    expect(qp is StringPropertyQuery, true);
    qp.close();

  });

  test(".min .max .sum", () {
    box.putMany(integerList);

    final query = box.query(((tLong < 2) | (tShort > 0)) as Condition).build();

    tIntegers.forEach((i) {
      final qp = query.property(i) as IntegerPropertyQuery;

      expect(qp.min(), 0); // TODO change

      expect(qp.max(), 0); // TODO change

      expect(qp.sum(), 0); // TODO change

      qp.close();
    });

    query.close();
  });

  test(".find", () {
    box.putMany(integerList);

//    final query = box.query(((tLong < 2 | tString.endsWith("suffix")) as Condition) | tDouble.between(0.0, 0.2)) as Condition).build();
    final query = box.query(tLong.lessThan(2).or(tString.endsWith("suffix")).or(tDouble.between(0.0, 0.2))).build();

    tIntegers.forEach((i) {
      final qp = query.property(i) as IntegerPropertyQuery;

      expect(qp.find(), 0); // TODO change
      expect(qp.find(defaultValue:-1), 0); // TODO change

      qp.close();
    });

    tFloats.forEach((f) {
      final qp = query.property(f) as DoublePropertyQuery;

      expect(qp.find(), 0); // TODO change
      expect(qp.find(defaultValue:-0.1), 0); // TODO change

      qp.close();
    });

    final qp = query.property(tString) as StringPropertyQuery;

    expect(qp.find(), ""); // TODO change
    expect(qp..distinct(true) ..caseSensitive(true)..find(), ""); // TODO change
    expect(qp..distinct(false)..caseSensitive(true)..find(defaultValue:"meh"), ""); // TODO change
    expect(qp..distinct(true) ..caseSensitive(false)..find(), ""); // TODO change
    expect(qp..distinct(false) ..caseSensitive(false)..find(defaultValue:"meh"), ""); // TODO change
    expect(qp..distinct(true) ..caseSensitive(true)..find(), ""); // TODO change
    expect(qp..distinct(false)..caseSensitive(true)..find(defaultValue:"meh"), ""); // TODO change
    expect(qp..distinct(true) ..caseSensitive(false)..find(), ""); // TODO change
    expect(qp..distinct(false)..caseSensitive(false)..find(defaultValue:"meh"), ""); // TODO change
    qp.close();

    query.close();
  });

  test(".average", () {
    final query = box.query(tLong.lessThan(2).or(tString.endsWith("suffix")).or(tDouble.between(0.0, 0.2))).build();

    tIntegers.forEach((i) {
      final qp = query.property(i) as IntegerPropertyQuery;

      expect(qp.average(), 0); // TODO change

      qp.close();
    });

    tFloats.forEach((f) {
      final qp = query.property(f) as DoublePropertyQuery;

      expect(qp.average(), 0.0); // TODO change

      qp.close();
    });

    query.close();
  });

  tearDown(() {
    env.close();
  });
}

