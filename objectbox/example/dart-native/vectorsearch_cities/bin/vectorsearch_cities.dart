import 'package:vectorsearch_cities/objectbox.dart';

void main(List<String> arguments) {
  final objectBox = ObjectBox.create();

  // Retrieve IDs
  final resultIds = objectBox.findTwoClosestNeighborsIds();
  for (final result in resultIds) {
    print("City ID: ${result.id}, distance: ${result.score}");
  }

  // Retrieve objects
  final results = objectBox.findTwoClosestNeighbors();
  for (final result in results) {
    print("City: ${result.object.name}, distance: ${result.score}");
  }
}
