import 'package:objectbox/objectbox.dart';

@Entity()
class Person {
  @Id()
  int id = 0;

  @Index()
  String name;

  @Unique()
  String? email;

  int age;
  double height;
  bool active;

  @Property(type: PropertyType.date)
  DateTime? birthday;

  List<String>? tags;

  @HnswIndex(dimensions: 3)
  @Property(type: PropertyType.floatVector)
  List<double>? embedding;

  final home = ToOne<House>();
  final friends = ToMany<Person>();

  Person(
      {required this.name,
      this.email,
      this.age = 0,
      this.height = 0,
      this.active = true,
      this.birthday,
      this.tags,
      this.embedding});
}

@Entity()
class House {
  @Id()
  int id = 0;

  String address;

  @Backlink('home')
  final residents = ToMany<Person>();

  House(this.address);
}
