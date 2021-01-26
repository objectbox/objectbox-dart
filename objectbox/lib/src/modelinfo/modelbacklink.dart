/// ModelBacklink describes a relation backlink
class ModelBacklink {
  final String name;

  final String srcEntity;

  final String srcField;

  ModelBacklink(this.name, this.srcEntity, this.srcField);

  ModelBacklink.fromMap(Map<String, dynamic> data)
      : this(data['name'], data['srcEntity'], data['srcField']);

  Map<String, dynamic> toMap() =>
      {'name': name, 'srcEntity': srcEntity, 'srcField': srcField};

  @override
  String toString() => 'relation backlink $name from $srcEntity.$srcField';
}
