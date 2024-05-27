import 'model.dart';
import 'objectbox.g.dart';

/// Provides access to the ObjectBox Store throughout the app.
class ObjectBox {
  /// The Store of this app.
  late final Store _store;

  late final Box<City> _cityBox;

  ObjectBox._create(this._store) {
    _cityBox = Box<City>(_store);

    if (_cityBox.isEmpty()) {
      _putCityData();
    }
  }

  /// Create an instance of ObjectBox to use throughout the app.
  static ObjectBox create() {
    // Note: set macosApplicationGroup for sandboxed macOS applications, see the
    // Store documentation for details.

    // Store openStore() {...} is defined in the generated objectbox.g.dart
    final store = openStore(
        directory: "obx-demo-vectorsearch-cities",
        macosApplicationGroup: "objectbox.demo");
    return ObjectBox._create(store);
  }

  _putCityData() {
    _cityBox.putMany([
      City("Barcelona", [41.385063, 2.173404]),
      City("Nairobi", [-1.292066, 36.821945]),
      City("Salzburg", [47.809490, 13.055010]),
    ]);
  }

  Query<City> _queryTwoClosestNeighbors() {
    final madrid = [40.416775, -3.703790]; // query vector
    // Prepare a Query object to search for the 2 closest neighbors:
    final query =
        _cityBox.query(City_.location.nearestNeighborsF32(madrid, 2)).build();

    // Combine with other conditions as usual
    // ignore: unused_local_variable
    final queryCombined = _cityBox
        .query(City_.location
            .nearestNeighborsF32(madrid, 2)
            .and(City_.name.startsWith("B")))
        .build();

    return query;
  }

  List<IdWithScore> findTwoClosestNeighborsIds() {
    final query = _queryTwoClosestNeighbors();
    final results = query.findIdsWithScores();
    query.close();
    return results;
  }

  List<ObjectWithScore<City>> findTwoClosestNeighbors() {
    final query = _queryTwoClosestNeighbors();
    final results = query.findWithScores();
    query.close();
    return results;
  }
}
