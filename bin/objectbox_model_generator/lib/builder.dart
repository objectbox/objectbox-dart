import "package:build/build.dart";
import "package:source_gen/source_gen.dart";
import "package:objectbox_model_generator/src/generator.dart";

Builder objectboxModelFactory(BuilderOptions options) => SharedPartBuilder([EntityGenerator()], "objectbox_model");
