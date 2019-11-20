import "package:build/build.dart";
import "package:source_gen/source_gen.dart";
import "src/entity_binding.dart";

Builder entityBindingBuilder(BuilderOptions options) => SharedPartBuilder([EntityGenerator()], "objectbox_entity");

