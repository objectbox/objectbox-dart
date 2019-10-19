# ObjectBox Dart – Code generation

To make it possible to read and write ObjectBox entity instances as easily as possible, wrapper code needs to be generated. Such code is only generated for Dart classes which have been annotated to indicate that they represent an ObjectBox entity (i.e. using [`@Entity`](/lib/src/annotations.dart#L1)). For a Dart source file called `myentity.dart`, which contains an entity definition, a file called `myentity.g.dart` is generated in the same directory by invoking the command `pub run build_runner build`.

Unfortunately, only few documentation exists on how to generate code using Dart's `build`, `source_gen` and `build_runner`, so the approach taken here by `objectbox_model_generator` is documented in the following.

## Basics

In order to set up code generation, a new package needs to be created exclusively for this task. Here, it it called `objectbox_model_generator`. This package needs to contain a file called [`build.yaml`](/bin/objectbox_model_generator/build.yaml) as well as an entry point for the builder, [`builder.dart`](/bin/objectbox_model_generator/lib/builder.dart), and a generator specifically for one annotation class, [`generator.dart`](/bin/objectbox_model_generator/lib/src/generator.dart). The latter needs to contain a class which extends `GeneratorForAnnotation<obx.Entity>` and overrides `Future<String> generateForAnnotatedElement(Element elementBare, ConstantReader annotation, BuildStep buildStep)`, which returns a string containing the generated code for a single annotation instance.

It is then possible to traverse through the annotated class in `generateForAnnotatedElement` and e.g. determine all class member fields and their types. Additionally, such member fields can be annotated themselves, but because here, only the `@Entity` annotation is explicitly handled using a separate generator class, member annotations can be read and processed in line.

## Merging

After a class, e.g. `TestEntity` in [box_test.dart](/test/box_test.dart#L6), has been fully read, it needs to be compared against and merged with the existing model definition of this class from `objectbox-model.json`. This is done by the function `mergeEntity` in [`merge.dart`](/bin/objectbox_model_generator/lib/src/merge.dart). This function takes the parameters `modelInfo`, the existing JSON model, and `readEntity`, the model class definition currently read from a user-provided Dart source file. For some more information on the merging process, see the existing documentation on [Data Model Updates](https://docs.objectbox.io/advanced/data-model-updates); it should also be helpful to refer to the comments in `merge.dart`.

Also note that in this step, IDs and UIDs are generated automatically for new instances. UIDs are always random, IDs are assigned in ascending order. UIDs may never be reused, e.g. after a property has been removed. This is why `ModelInfo` contains, among others, a member variable called `retiredPropertyUids`, which contains an array of all UIDs which have formerly been assigned to properties, and which are now unavailable to all entities.

Eventually, `mergeEntity` either throws an error in case the model cannot be merged (e.g. because of ambiguities) or, after having returned normally, it has modified its `modelInfo` parameter to include the entity changes.

## Testing

For accomplishing actually automated testing capabilities for `objectbox_model_generator`, various wrapper classes are needed, as the `build` package is only designed to generate output _files_; yet, during testing, it is necessary to dump generated code to string variables, so they can be compared easily by Dart's `test` framework.

The entry function for generator testing is the main function of [`generator_test.dart`](/bin/objectbox_model_generator/test/generator_test.dart). It makes sure that any existing file called `objectbox-model.json` is removed before every test, because we want a fresh start each time.

### Helper classes

The `build` package internally uses designated classes for reading from and writing to files or, to be more general, any kind of _assets_. In this case, we do not want to involve any kind of files as output and only very specific files as input, so it is necessary to create our own versions of the so-called `AssetReader` and `AssetWriter`.

In [`helpers.dart`](/bin/objectbox_model_generator/test/helpers.dart), `_InMemoryAssetWriter` is supposed to receive a single output string and store it in memory. Eventually, the string it stores will be the output of [`EntityGenerator`](/bin/objectbox_model_generator/lib/src/generator.dart#L15).

On the other hand, `_SingleFileAssetReader` shall read a single input Dart source file from the [`test/cases`](/bin/objectbox_model_generator/test/cases) directory. Note that currently, test cases have the rather ugly file extension `.dart_testcase`, such as [`single_entity.dart_testcase`](/bin/objectbox_model_generator/test/cases/single_entity/single_entity.dart_testcase). This is a workaround, because otherwise, running `pub run build_runner build` in the repository's root directory would generate `.g.dart` files from _all_ `.dart` files in the repository. An option to exclude certain directories from `build_runner` is yet to be found.

### Executing the tests

Eventually, the function `runBuilder` [can be executed](/bin/objectbox_model_generator/test/helpers.dart#L62), which is part of the `build` package. It encapsulates everything related to generating the final output. Thus, after it is finished and in case generation was successful, the `_InMemoryAssetWriter` instance contains the generated code, which can then be compared against the expected code.
