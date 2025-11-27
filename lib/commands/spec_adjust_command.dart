import 'dart:io';
import 'package:args/command_runner.dart';
import '../utils/spec_adjuster.dart';

/// Adjust OpenAPI spec for compatibility with swagger_dart_code_generator
class SpecAdjustCommand extends Command<void> {
  @override
  String get name => 'spec-adjust';

  @override
  String get description =>
      'Adjust OpenAPI 3.0 spec to be compatible with swagger_dart_code_generator';

  SpecAdjustCommand() {
    argParser
      ..addOption(
        'spec-file',
        abbr: 's',
        help: 'Path to the OpenAPI spec file',
        mandatory: true,
      )
      ..addFlag(
        'no-backup',
        negatable: false,
        help: 'Skip creating a backup file',
      )
      ..addFlag(
        'validate-only',
        abbr: 'v',
        negatable: false,
        help: 'Only validate the spec without making changes',
      );
  }

  @override
  Future<void> run() async {
    final results = argResults!;
    final specFile = results['spec-file'] as String;
    final backup = !(results['no-backup'] as bool);
    final validateOnly = results['validate-only'] as bool;

    print('═' * 70);
    print('  OpenAPI Spec Adjuster');
    print('═' * 70);
    print('Spec file: $specFile\n');

    try {
      // Validate spec exists
      if (!await File(specFile).exists()) {
        stderr.writeln('Error: Spec file not found at: $specFile');
        exit(1);
      }

      if (validateOnly) {
        print('┌─ Validating spec...');
        final isValid = await validateSpec(specFile);
        if (isValid) {
          print('└─ ✓ Spec is valid\n');
        } else {
          stderr.writeln('└─ ✗ Spec validation failed\n');
          exit(1);
        }
        return;
      }

      print('┌─ Adjusting spec for compatibility...');
      print('│');

      final success = await adjustSpecForCompatibility(
        specFilePath: specFile,
        backup: backup,
      );

      if (success) {
        print('│');
        print('└─ ✓ Spec adjustment complete\n');

        print('═' * 70);
        print('  Next steps:');
        print('═' * 70);
        print('  Run code generation with:');
        print('  dart run build_runner build --delete-conflicting-outputs\n');
      } else {
        stderr.writeln('│');
        stderr.writeln('└─ ✗ Spec adjustment failed\n');
        exit(1);
      }
    } catch (e) {
      stderr.writeln('\n✗ Error: $e\n');
      exit(1);
    }
  }
}
