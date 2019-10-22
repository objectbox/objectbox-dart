# ObjectBox Dart – Model info

In order to represent the model stored in `objectbox-model.json` in Dart, several classes have been introduced. They can be found [here](/lib/src/modelinfo). Conceptually, these classes are comparable to how models are handled in ObjectBox Java and ObjectBox Go; eventually, ObjectBox Dart models will be fully compatible to them. This is also why for explanations on most concepts related to ObjectBox models, you can refer to the [existing documentation](https://docs.objectbox.io/advanced).

Nonetheless, the concrete implementation in this repository is documented in the following.

## IdUid

[IdUid](/lib/src/modelinfo/iduid.dart) represents a compound of an ID, which is locally unique, i.e. inside an entity, and a UID, which is globally unique, i.e. for the entire model. When this is serialized, the two numerical values are concatenated using a colon (`:`). See the documentation for more information on [IDs](https://docs.objectbox.io/advanced/meta-model-ids-and-uids#ids) and [UIDs](https://docs.objectbox.io/advanced/meta-model-ids-and-uids#uids).

## Model classes

- [`ModelProperty`](/lib/src/modelinfo/modelproperty.dart) describes a single property of an entity, i.e. its id, name, type and flags
- [`ModelEntity`](/lib/src/modelinfo/modelentity.dart) describes an entity of a model and consists of instances of `ModelProperty` as well as an id, name and last property id
- [`ModelInfo`](/lib/src/modelinfo/modelinfo.dart) logically contains an entire ObjectBox model file like [this one](/objectbox-model.json) and thus consists of an array of `ModelEntity` as well as various meta information for ObjectBox and model version information

Such model meta information is only actually needed when generating `objectbox-model.json`, i.e. when `objectbox_model_generator` is invoked. This is the case in [`generator.dart`](/generator/lib/src/generator.dart#L24). In [generated code](/generator/lib/src/code_chunks.dart#L12), the JSON file is loaded in the same way, but only the `ModelEntity` instances are kept.
