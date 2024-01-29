// ignore_for_file: public_member_api_docs

import 'modelproperty.dart';
import 'modelrelation.dart';

/// ModelBacklink describes a relation backlink
class ModelBacklink {
  final String name;

  final String srcEntity;

  final String srcField;

  /// Set and used by code generator, not included in JSON mapping.
  BacklinkSource? source;

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

/// Contains either a source property (backlink from to-one) or a source
/// relation (backlink from to-many).
abstract class BacklinkSource {}

class BacklinkSourceProperty extends BacklinkSource {
  ModelProperty srcProp;

  BacklinkSourceProperty(this.srcProp);
}

class BacklinkSourceRelation extends BacklinkSource {
  ModelRelation srcRel;

  BacklinkSourceRelation(this.srcRel);
}
