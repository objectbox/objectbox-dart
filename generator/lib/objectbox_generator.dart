import "package:build/build.dart";
import "src/entity_resolver.dart";
import "src/code_builder.dart";

Builder entityResolverFactory(BuilderOptions options) => EntityResolver();

Builder codeGeneratorFactory(BuilderOptions options) => CodeBuilder();
