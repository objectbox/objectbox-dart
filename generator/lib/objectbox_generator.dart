import 'package:build/build.dart';
import 'src/entity_resolver.dart';
import 'src/code_builder.dart';

/// Finds all classes annotated with @Entity annotation and creates intermediate files for the generator.
Builder entityResolverFactory(BuilderOptions options) => EntityResolver();

/// Writes objectbox_model.dart and objectbox-model.json from the prepared .objectbox.info files found in the repo.
Builder codeGeneratorFactory(BuilderOptions options) => CodeBuilder();
