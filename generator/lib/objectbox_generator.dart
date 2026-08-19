/// This package provides code generation for ObjectBox in Dart/Flutter.
library;

import 'package:build/build.dart';

import 'src/code_builder.dart';
import 'src/config.dart';
import 'src/entity_resolver.dart';

final _config = Config.readFromPubspec();

/// Finds all classes annotated with @Entity annotation and creates intermediate files for the generator.
Builder entityResolverFactory(BuilderOptions options) => EntityResolver();

/// Writes objectbox_model.dart and objectbox-model.json from the prepared .objectbox.info files found in the repo.
Builder codeGeneratorFactory(BuilderOptions options) => CodeBuilder(_config);
