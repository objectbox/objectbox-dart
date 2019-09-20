import "dart:async";
import "package:analyzer/dart/element/element.dart";
import "package:build/src/builder/build_step.dart";
import "package:source_gen/source_gen.dart";

import "package:objectbox/objectbox.dart";
import "package:objectbox/src/bindings/constants.dart";

class EntityGenerator extends GeneratorForAnnotation<Entity> {
  @override
  FutureOr<String> generateForAnnotatedElement(Element elementBare, ConstantReader annotation, BuildStep buildStep) {
    if (elementBare is! ClassElement)
      throw InvalidGenerationSourceError("in target ${elementBare.name}: annotated element isn't a class");

    // get basic entity info
    var entity = Entity(id: annotation.read('id').intValue, uid: annotation.read('uid').intValue);
    var element = elementBare as ClassElement;
    var ret = """
        const _${element.name}_OBXModel = {
          "entity": {
            "name": "${element.name}",
            "id": ${entity.id},
            "uid": ${entity.uid}
          },
          "properties": [
      """;

    // read all suitable annotated properties
    var props = [];
    String idPropertyName;
    for (var f in element.fields) {
      if (f.metadata == null || f.metadata.length != 1) // skip unannotated fields
        continue;
      var annotElmt = f.metadata[0].element as ConstructorElement;
      var annotType = annotElmt.returnType.toString();
      var annotVal = f.metadata[0].computeConstantValue();
      var fieldTypeObj = annotVal.getField("type");
      int fieldType = fieldTypeObj == null ? null : fieldTypeObj.toIntValue();

      var prop = {
        "name": f.name,
        "id": annotVal.getField("id").toIntValue(),
        "uid": annotVal.getField("uid").toIntValue(),
        "flags": 0,
      };

      if (annotType == "Id") {
        if (idPropertyName != null)
          throw InvalidGenerationSourceError(
              "in target ${elementBare.name}: has more than one properties annotated with @Id");
        if (fieldType != null)
          throw InvalidGenerationSourceError(
              "in target ${elementBare.name}: programming error: @Id property may not specify a type");
        if (f.type.toString() != "int")
          throw InvalidGenerationSourceError(
              "in target ${elementBare.name}: field with @Id property has type '${f.type.toString()}', but it must be 'int'");

        fieldType = OBXPropertyType.Long;
        prop["flags"] = OBXPropertyFlag.ID;
        idPropertyName = f.name;
      } else if (annotType == "Property") {
        // nothing special here
      } else {
        // skip unknown annotations
        continue;
      }

      if (fieldType == null) {
        var fieldTypeStr = f.type.toString();
        if (fieldTypeStr == "int")
          fieldType = OBXPropertyType.Int;
        else if (fieldTypeStr == "String")
          fieldType = OBXPropertyType.String;
        else {
          print(
              "warning: skipping field '${f.name}' in entity '${element.name}', as it has the unsupported type '$fieldTypeStr'");
          continue;
        }
      }

      prop["type"] = fieldType;
      props.add(prop);
      ret += """
          {
            "name": "${prop['name']}",
            "id": ${prop['id']},
            "uid": ${prop['uid']},
            "type": ${prop['type']},
            "flags": ${prop['flags']},
          },
        """;
    }

    // some checks on the entity's integrity
    if (idPropertyName == null)
      throw InvalidGenerationSourceError("in target ${elementBare.name}: has no properties annotated with @Id");

    // main code for instance builders and readers
    ret += """
          ],
          "idPropertyName": "${idPropertyName}",
        };

        ${element.name} _${element.name}_OBXBuilder(Map<String, dynamic> members) {
          ${element.name} r = new ${element.name}();
          ${props.map((p) => "r.${p['name']} = members[\"${p['name']}\"];").join()}
          return r;
        }

        Map<String, dynamic> _${element.name}_OBXReader(${element.name} inst) {
          Map<String, dynamic> r = {};
          ${props.map((p) => "r[\"${p['name']}\"] = inst.${p['name']};").join()}
          return r;
        }

        const ${element.name}_OBXDefs = {
          "model": _${element.name}_OBXModel,
          "builder": _${element.name}_OBXBuilder,
          "reader": _${element.name}_OBXReader,
        };
      """;

    ret += """
    class ${element.name}_ {
    """;

    ret += """
      static final entityId = ${entity.id};
    """;

    for (var f in element.fields) {
      if (f.metadata == null ||
          f.metadata.length != 1) // skip unannotated fields
        continue;

      var annotElmt = f.metadata[0].element as ConstructorElement;
      var annotType = annotElmt.returnType.toString();
      var annotVal = f.metadata[0].computeConstantValue();
      var annotValId = annotVal.getField("id").toIntValue();

      if ("Id" == annotType) continue;

      var fieldType = f.type.toString();
      if ("int" == fieldType) {
        fieldType = "Integer";
      }else if ("double" == fieldType) {
        fieldType = "Double";
      }else if ("bool" == fieldType) {
        fieldType = "Boolean";
      }

      ret += """
        static final ${f.name}PropertyId = ${annotValId};
        static final ${f.name} = Query${fieldType}Property(entityId, ${f.name}PropertyId);
      """;
    }

      ret += """
    }
    """;

    return ret;
  }
}
