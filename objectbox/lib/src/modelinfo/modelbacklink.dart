// ignore_for_file: public_member_api_docs

/// ModelBacklink describes a relation backlink
class ModelBacklink {
  final String name;

  final String srcEntity;

  final String srcField;

  ModelBacklink(this.name, this.srcEntity, this.srcField);

  ModelBacklink.fromMap(Map<String, dynamic> data)
      : this(data['name'] as String /*!*/, data['srcEntity'] as String /*!*/,
            data['srcField'] as String /*!*/);

  Map<String, String> toMap() =>
      {'name': name, 'srcEntity': srcEntity, 'srcField': srcField};

  @override
  String toString() => 'relation backlink $name from $srcEntity.$srcField';
}
