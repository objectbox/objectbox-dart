import 'package:objectbox/src/bindings/constants.dart';

bool listContains<T>(List<T> list, T item) =>
    list.indexWhere((x) => x == item) != -1;

extension Indexer on int {
  bool get isIndexer =>
      this & OBXPropertyFlag.INDEXED == 8 ||
      this & OBXPropertyFlag.UNIQUE == 32;
}
