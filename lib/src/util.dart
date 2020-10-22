import 'package:objectbox/src/bindings/constants.dart';

bool listContains<T>(List<T> list, T item) =>
    list.indexWhere((x) => x == item) != -1;

extension PropertyType on int {
  bool get isRelation => this == OBXPropertyType.Relation;
}
