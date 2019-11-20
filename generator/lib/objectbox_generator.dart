import "package:build/build.dart";
import "src/entity_resolver.dart";
import "src/code_builder.dart";

// See docs
// https://github.com/dart-lang/build/blob/master/docs/writing_a_builder.md
// https://github.com/dart-lang/build/blob/master/docs/writing_an_aggregate_builder.md
// https://pub.dev/packages/build_config#configuring-builders-applied-to-your-package

Builder entityResolverFactory(BuilderOptions options) => EntityResolver();

Builder codeGeneratorFactory(BuilderOptions options) => CodeBuilder();
