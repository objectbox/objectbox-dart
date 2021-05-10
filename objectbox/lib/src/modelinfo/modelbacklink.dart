// ignore_for_file: public_member_api_docs

/// ModelBacklink describes a relation backlink
class ModelBacklink {
  final String name;

  final String srcEntity;

  final String srcField;

  ModelBacklink(
      {required this.name, required this.srcEntity, required this.srcField});

  ModelBacklink.fromMap(Map<String, dynamic> data)
      : this(
            name: data['name'] as String,
            srcEntity: data['srcEntity'] as String,
            srcField: data['srcField'] as String);

  Map<String, String> toMap() =>
      {'name': name, 'srcEntity': srcEntity, 'srcField': srcField};

  @override
  String toString() => 'relation backlink $name from $srcEntity.$srcField';
}
