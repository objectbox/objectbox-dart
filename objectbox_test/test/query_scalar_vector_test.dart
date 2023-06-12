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

    for (int i = 0; i < properties.length; i++) {
      var property = properties[i];

      // Note: regular conditions currently not supported by C library.

      final queryNull = box.query(property.isNull()).build();
      expect(queryNull.findIds(), []);
      queryNull.close();

      final queryNotNull = box.query(property.notNull()).build();
      expect(queryNotNull.findIds(), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      queryNotNull.close();
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

    for (int i = 0; i < properties.length; i++) {
      var property = properties[i];

      // Note: regular conditions currently not supported by C library.

      final queryNull = box.query(property.isNull()).build();
      expect(queryNull.findIds(), []);
      queryNull.close();

      final queryNotNull = box.query(property.notNull()).build();
      expect(queryNotNull.findIds(), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      queryNotNull.close();
    }
  });
}
