import 'package:test/test.dart';
import 'entity.dart';
import 'objectbox.g.dart';
import 'test_env.dart';

void main() {
  late TestEnv env;

  setUp(() {
    env = TestEnv('query-scalar-vector');
  });

  tearDown(() => env.closeAndDelete());

  test("integer vectors", () {
    final box = env.store.box<TestEntityScalarVectors>();

    var testEntities = TestEntityScalarVectors.createTen();
    box.putMany(testEntities);

    final properties = [
      TestEntityScalarVectors_.tShortList,
      TestEntityScalarVectors_.tIntList,
      TestEntityScalarVectors_.tLongList
    ];

    final paramsLarger = [
      1010, // short
      100010, // int
      10000000010 // long
    ];

    final params5 = [
      1004, // short
      100004, // int
      10000000004 // long
    ];

    final params10 = [
      1009, // short
      100009, // int
      10000000009 // long
    ];

    for (int i = 0; i < properties.length; i++) {
      final property = properties[i];
      final pLarger = paramsLarger[i];
      final p5 = params5[i];
      final p10 = params10[i];

      // "greater" which behaves like "has element greater"
      final qGreater = box.query(property.greaterThan(pLarger)).build();
      expect(qGreater.findIds(), []);
      qGreater.param(property).value = p5;
      expect(qGreater.findIds(), [6, 7, 8, 9, 10]);
      qGreater.close();

      // "greater or equal", only check equal
      final qGreaterOrEq = box.query(property.greaterOrEqual(p10)).build();
      expect(qGreaterOrEq.findIds(), [10]);
      qGreaterOrEq.close();

      // "less" which behaves like "has element less".
      final qLess = box.query(property.lessThan(-pLarger)).build();
      expect(qLess.findIds(), []);
      qLess.param(property).value = -p5;
      expect(qLess.findIds(), [6, 7, 8, 9, 10]);
      qLess.close();

      // "less or equal", only check equal
      final qLessOrEq = box.query(property.lessOrEqual(-p10)).build();
      expect(qLessOrEq.findIds(), [10]);
      qLessOrEq.close();

      // "equal" which behaves like "contains element".
      final qEq = box.query(property.equals(-1)).build();
      expect(qEq.findIds(), []);
      qEq.param(property).value = p5;
      expect(qEq.findIds(), [5]);
      qEq.close();

      // Note: "not equal" for scalar arrays does not do anything useful.
    }
  });

  test("floating point vectors", () {
    final box = env.store.box<TestEntityScalarVectors>();

    var testEntities = TestEntityScalarVectors.createTen();
    box.putMany(testEntities);

    final paramsLarger = [
      21.0, // float
      2000.0001, // double
    ];

    final params5 = [
      20.4, // float
      2000.00004, // double
    ];

    final params10 = [
      20.9, // float
      2000.00009, // double
    ];

    final properties = [
      TestEntityScalarVectors_.tFloatList,
      TestEntityScalarVectors_.tDoubleList
    ];

    for (int i = 0; i < properties.length; i++) {
      final property = properties[i];
      final pLarger = paramsLarger[i];
      final p5 = params5[i];
      final p10 = params10[i];

      // "greater" which behaves like "has element greater"
      final qGreater = box.query(property.greaterThan(pLarger)).build();
      expect(qGreater.findIds(), []);
      qGreater.param(property).value = p5;
      expect(qGreater.findIds(), [6, 7, 8, 9, 10]);
      qGreater.close();

      // "greater or equal", only check equal
      final qGreaterOrEq = box.query(property.greaterOrEqual(p10)).build();
      expect(qGreaterOrEq.findIds(), [10]);
      qGreaterOrEq.close();

      // "less" which behaves like "has element less".
      final qLess = box.query(property.lessThan(-pLarger)).build();
      expect(qLess.findIds(), []);
      qLess.param(property).value = -p5;
      expect(qLess.findIds(), [6, 7, 8, 9, 10]);
      qLess.close();

      // "less or equal", only check equal
      final qLessOrEq = box.query(property.lessOrEqual(-p10)).build();
      expect(qLessOrEq.findIds(), [10]);
      qLessOrEq.close();
    }
  });
}
