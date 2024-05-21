import 'package:objectbox/objectbox.dart';

@Entity()
class City {
  @Id()
  int id = 0;

  String? name;

  @HnswIndex(dimensions: 2)
  @Property(type: PropertyType.floatVector)
  List<double>? location;

  City(this.name, this.location);
}
