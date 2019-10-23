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

  test(".distinct, .count, .close property query", () {
    box.putMany(integerList);
    box.putMany(stringList);
    box.putMany(floatList);

    final query = box.query((tLong < 2) as Condition).build();
    final queryInt = query.property(tLong);

    final tLongCount = queryInt.count();

    expect(tLongCount, 4);

    queryInt.close();
    query.close();

    /*
    final tLongDistinctCount = queryInt..distinct(true)..count();

    expect(4, tLongCount);
    expect(2, tLongDistinctCount);

    query.close();
    queryInt.close();
     */
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

  tearDown(() {
    env.close();
  });
}
