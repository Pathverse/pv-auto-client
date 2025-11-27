import 'dart:io';
import 'package:args/command_runner.dart';
import '../utils/build_maker.dart';
import '../utils/pubspec_updater.dart';

/// Setup target project with required dependencies and build configuration
class SetupCommand extends Command<void> {
  @override
  String get name => 'setup';

  @override
  String get description =>
      'Setup target Dart project with required dependencies and build.yaml';

  SetupCommand() {
    argParser
      ..addOption(
        'target',
        abbr: 't',
        help: 'Target Dart/Flutter project path',
        defaultsTo: Directory.current.path,
      )
      ..addOption(
        'output-dir',
        help: 'Output directory for generated code',
        defaultsTo: 'lib/generated',
      )
      ..addOption(
        'input-dir',
        help: 'Input directory for spec files',
        defaultsTo: 'specs',
      )
      ..addFlag(
        'force',
        abbr: 'f',
        negatable: false,
        help: 'Force overwrite existing files and add dependencies',
      )
      ..addFlag(
        'run-pub-get',
        abbr: 'p',
        negatable: false,
        help: 'Automatically run dart pub get after adding dependencies',
      );
  }

  @override
  Future<void> run() async {
    final results = argResults!;
    final targetPath = results['target'] as String;
    final outputDir = results['output-dir'] as String;
    final inputDir = results['input-dir'] as String;
    final force = results['force'] as bool;
    final runPubGet = results['run-pub-get'] as bool;

    try {
      print('Setting up target project: $targetPath\n');

      // Step 1: Validate target is a Dart/Flutter project
      print('[1/3] Validating target project...');
      final isValid = await validateTargetProject(targetPath);
      if (!isValid) {
        stderr.writeln('\nSetup failed: Target is not a valid Dart project');
        exit(1);
      }
      print('');

      // Step 2: Add required dependencies
      print('[2/3] Checking and adding dependencies...');
      final depsAdded = await addRequiredDependencies(
        targetProjectPath: targetPath,
        force: force,
      );

      if (!depsAdded && !force) {
        stderr.writeln(
          '\nSetup incomplete: Add --force flag to add dependencies automatically',
        );
        exit(1);
      }
      print('');

      // Step 3: Create build.yaml
      print('[3/3] Creating build.yaml configuration...');
      final buildCreated = await createBuildYaml(
        targetProjectPath: targetPath,
        inputFolder: inputDir,
        outputDirectory: outputDir,
        force: force,
      );

      if (!buildCreated) {
        stderr.writeln('\nSetup incomplete: Failed to create build.yaml');
        exit(1);
      }
      print('');

      // Step 4: Run pub get if requested
      if (runPubGet && depsAdded) {
        print('Running dart pub get...');
        final result = await Process.run('dart', [
          'pub',
          'get',
        ], workingDirectory: targetPath);

        if (result.exitCode == 0) {
          print('✓ Dependencies installed successfully');
          stdout.write(result.stdout);
        } else {
          stderr.writeln('Error running dart pub get:');
          stderr.write(result.stderr);
        }
        print('');
      }

      // Success summary
      print('━' * 60);
      print('✓ Setup complete!');
      print('━' * 60);
      print('');
      print('Next steps:');
      if (!runPubGet && depsAdded) {
        print('  1. Run: cd $targetPath && dart pub get');
      }
      print(
        '  ${runPubGet ? '1' : '2'}. Download spec: pv_auto_client download-spec --output-path $targetPath',
      );
      print(
        '  ${runPubGet ? '2' : '3'}. Generate code: cd $targetPath && dart run build_runner build',
      );
      print('');
    } catch (e) {
      stderr.writeln('Error during setup: $e');
      exit(1);
    }
  }
}
