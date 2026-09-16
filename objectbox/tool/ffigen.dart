import 'dart:io';

import 'package:ffigen/ffigen.dart';
import 'package:path/path.dart' as path;

/// Generates lib/src/native/bindings/objectbox_c.dart from the C headers
/// (migrated from the former `ffigen` section in pubspec.yaml).
///
/// Run via: ./tool/update-c-binding.sh
///
/// Any command line arguments are passed to clang as compiler options, e.g.
/// the include path for its builtin headers added by the `--clang-fix` option
/// of the script.
///
/// See /dev-doc/updating-c-library.md for details.
///
/// Docs at https://pub.dev/packages/ffigen
Future<void> main(List<String> args) async {
  final packageRoot = Platform.script.resolve('../');

  // Expose some native pointers to use with NativeFinalizer API.
  // https://pub.dev/packages/ffigen#how-to-expose-the-native-pointers
  const symbolAddressFunctions = {
    'obx_admin_close',
    'obx_observer_close',
    'obx_query_close',
    'obx_query_prop_close',
    'obx_store_close',
    'obx_txn_close',
  };

  final generator = FfiGenerator(
    input: Input(
      entryPoints: [
        // NOTE: replace `const void*` by `const uint8_t*` in all objectbox*.h
        // files when upgrading. This is to avoid casting Pointer<Uint8> to
        // Pointer<Void> in Dart.
        packageRoot.resolve('lib/src/native/bindings/objectbox.h'),
        packageRoot.resolve('lib/src/native/bindings/objectbox-dart.h'),
      ],
      // Was include-directives: '**objectbox*.h'
      include: (header) {
        final fileName = path.basename(header.toFilePath());
        return fileName.startsWith('objectbox') && fileName.endsWith('.h');
      },
      // Was passed via the command line with --compiler-opts.
      compilerOptions: args.isEmpty ? null : args,
    ),
    output: Output(
      dart: DartOutput(
        path: packageRoot.resolve('lib/src/native/bindings/objectbox_c.dart'),
      ),
      // Was name/description: generate a wrapper class taking a DynamicLibrary.
      style: const DynamicLibraryBindings(
        wrapperName: 'ObjectBoxC',
        wrapperDocComment: 'Bindings to ObjectBox C-API',
      ),
      // pana ignores exclude rules in analysis_options.yaml, explicitly add
      // ignore rules.
      preamble: '''
// ignore_for_file: non_constant_identifier_names, public_member_api_docs, prefer_expression_function_bodies, avoid_positional_boolean_parameters, constant_identifier_names, camel_case_types
''',
    ),
    visitors: [
      Visitor(
        func: (node) {
          node.isIncluded = true;
          // Was functions.rename:
          // 'obx_dart_(.*)': 'dartc_$1'
          // 'obx_(.*)': '$1'
          final originalName = node.originalName;
          if (originalName.startsWith('obx_dart_')) {
            node.name = originalName.replaceFirst('obx_dart_', 'dartc_');
          } else if (originalName.startsWith('obx_')) {
            node.name = originalName.replaceFirst('obx_', '');
          }
          // Was functions.symbol-address.include
          if (symbolAddressFunctions.contains(originalName)) {
            node.exposeSymbolAddress = true;
          }
        },
        struct: (node) => node.isIncluded = true,
        enumClass: (node) {
          node.isIncluded = true;
          // Generate enums as integer constants (like before ffigen v8): the
          // code base uses the values as integers throughout (bit flags, model
          // JSON, generated code). Was enums.as-int.
          node.style = EnumStyle.intConstants;
        },
        enumConstant: (node) {
          // Was enums.member-rename: removes anything before the first '_',
          // i.e. OBXOrderFlags_CASE_SENSITIVE becomes CASE_SENSITIVE.
          final match = RegExp(r'^[^_]+_(.*)$').firstMatch(node.originalName);
          if (match != null) {
            node.name = match.group(1)!;
          }
        },
        // Macro constants are used for return and error codes.
        macroConstant: (node) => node.isIncluded = true,
        typealias: (node) => node.isIncluded = TypealiasInclude.ifUsed,
      ),
    ],
  );
  await generator.generate();
}
