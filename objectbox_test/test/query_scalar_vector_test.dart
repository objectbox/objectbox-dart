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

    final params5 = [14, 1004, 100004, 10000000004];

    for (int i = 0; i < properties.length; i++) {
      var property = properties[i];
      var param5 = params5[i];

      // "greater" which behaves like "has element greater".
      // FIXME Fails with "Property is not a integer scalar type: ShortVector (OBX_ERROR code 10002)"
      final query =
          box.query(property.greaterThan(100 * 1000 * 1000000)).build();
      expect(query.findIds(), []);
      query.param(property).value = param5;
      expect(query.findIds(), [6, 7, 8, 9, 10]);
      query.close();
    }
  });

  test("floating point vectors", () {
    final box = env.store.box<TestEntityScalarVectors>();

    var testEntities = TestEntityScalarVectors.createTen();
    box.putMany(testEntities);

    final properties = [
      TestEntityScalarVectors_.tFloatList,
      TestEntityScalarVectors_.tDoubleList
    ];

    final params5 = [20.4, 2000.00004];

    for (int i = 0; i < properties.length; i++) {
      var property = properties[i];
      var param5 = params5[i];

      // "greater" which behaves like "has element greater".
      // FIXME Fails with "Property is not a floating point scalar type: FloatVector (OBX_ERROR code 10002)"
      final query = box.query(property.greaterThan(2001.0)).build();
      expect(query.findIds(), []);
      query.param(property).value = param5;
      expect(query.findIds(), [6, 7, 8, 9, 10]);
      query.close();
    }
  });
}
