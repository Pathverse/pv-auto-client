import 'dart:io';
import 'package:args/command_runner.dart';
import '../utils/build_maker.dart';
import '../utils/pubspec_updater.dart';
import '../utils/postman_downloader.dart';

/// Complete automation: setup + download + generate
class AutoCommand extends Command<void> {
  @override
  String get name => 'auto';

  @override
  String get description =>
      'Automatically setup project, download spec (Swagger 2.0 by default), and generate code';

  AutoCommand() {
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
        'spec-dir',
        help: 'Directory for spec files',
        defaultsTo: 'specs',
      )
      ..addOption(
        'spec-file',
        abbr: 'f',
        help: 'Output spec filename',
        defaultsTo: 'api_spec.json',
      )
      ..addOption(
        'collection-uid',
        help: 'Postman collection UID (or set XCOID in .env)',
      )
      ..addOption(
        'format',
        help: 'Spec format: swagger2 or openapi3',
        allowed: ['swagger2', 'openapi3'],
        defaultsTo: 'swagger2',
      )
      ..addOption(
        'spec-id',
        help:
            'Postman spec ID (required for openapi3 format, or set XSPECID in .env)',
      )
      ..addFlag(
        'overwrite-dependencies',
        negatable: false,
        help: 'Check and ensure dependencies are up to date',
      )
      ..addFlag(
        'overwrite-build',
        negatable: false,
        help: 'Overwrite existing build.yaml',
      )
      ..addFlag(
        'skip-setup',
        negatable: false,
        help: 'Skip setup phase (dependencies and build.yaml)',
      )
      ..addFlag(
        'delete-conflicting',
        negatable: false,
        help: 'Delete conflicting outputs during generation',
        defaultsTo: true,
      );
  }

  @override
  Future<void> run() async {
    final results = argResults!;
    final targetPath = results['target'] as String;
    final outputDir = results['output-dir'] as String;
    final specDir = results['spec-dir'] as String;
    final specFile = results['spec-file'] as String;
    final collectionUid = results['collection-uid'] as String?;
    final format = results['format'] as String;
    final specId = results['spec-id'] as String?;
    final overwriteDependencies = results['overwrite-dependencies'] as bool;
    final overwriteBuild = results['overwrite-build'] as bool;
    final skipSetup = results['skip-setup'] as bool;
    final deleteConflicting = results['delete-conflicting'] as bool;

    print('═' * 70);
    print('  PV Auto Client - Automated Code Generation');
    print('═' * 70);
    print('Target: $targetPath\n');

    try {
      // Phase 0: Validate target is a Dart project
      print('┌─ Phase 0: Validation');
      print('│');
      final isValid = await validateTargetProject(targetPath);
      if (!isValid) {
        stderr.writeln('│');
        stderr.writeln('└─ ✗ Failed: Target is not a valid Dart project\n');
        exit(1);
      }
      print('└─ ✓ Target validated\n');

      // Phase 1: Setup (if not skipped)
      if (!skipSetup) {
        print('┌─ Phase 1: Setup');
        print('│');

        print('│  [1.1] Adding dependencies...');
        final depsAdded = await addRequiredDependencies(
          targetProjectPath: targetPath,
          force: overwriteDependencies,
        );

        if (!depsAdded && !overwriteDependencies) {
          stderr.writeln('│');
          stderr.writeln(
            '└─ ✗ Failed: Use --overwrite-dependencies to update dependencies\n',
          );
          exit(1);
        }

        print('│');
        print('│  [1.2] Creating build.yaml...');
        final buildCreated = await createBuildYaml(
          targetProjectPath: targetPath,
          inputFolder: specDir,
          outputDirectory: outputDir,
          force: overwriteBuild,
        );

        if (!buildCreated) {
          stderr.writeln('│');
          stderr.writeln(
            '└─ ✗ Failed to create build.yaml (use --overwrite-build to force)\n',
          );
          exit(1);
        }

        print('│');
        print('│  [1.3] Running dart pub get...');
        final pubResult = await Process.run('dart', [
          'pub',
          'get',
        ], workingDirectory: targetPath);

        if (pubResult.exitCode != 0) {
          stderr.writeln('│  Error: ${pubResult.stderr}');
          stderr.writeln('│');
          stderr.writeln('└─ ✗ Failed to install dependencies\n');
          exit(1);
        }

        print('└─ ✓ Setup complete\n');
      } else {
        print('⊘ Phase 1: Setup (skipped)\n');
      }

      // Phase 2: Download spec
      print('┌─ Phase 2: Download Spec ($format)');
      print('│');

      print('│  [2.1] Loading configuration...');
      final config = await loadPostmanConfig(targetPath);

      final finalCollectionUid = collectionUid ?? config.collectionUid;

      if (finalCollectionUid == null || finalCollectionUid.isEmpty) {
        stderr.writeln('│');
        stderr.writeln(
          '└─ ✗ Failed: Collection UID not provided and XCOID not found\n',
        );
        exit(1);
      }

      print('│');
      dynamic spec;

      if (format == 'swagger2') {
        print('│  [2.2] Downloading collection as Swagger 2.0...');
        spec = await fetchCollectionAsSwagger(
          config.apiKey,
          finalCollectionUid,
          targetPath,
          specFile,
        );

        if (spec == null) {
          stderr.writeln('│');
          stderr.writeln('└─ ✗ Failed to download collection as Swagger 2.0\n');
          exit(1);
        }

        print('└─ ✓ Swagger 2.0 spec ready for code generation\n');
      } else {
        // OpenAPI 3.0 mode
        final finalSpecId = specId ?? config.specId;

        if (finalSpecId == null || finalSpecId.isEmpty) {
          stderr.writeln('│');
          stderr.writeln(
            '└─ ✗ Failed: Spec ID required for OpenAPI 3.0 format\n',
          );
          exit(1);
        }

        print('│  [2.2] Updating spec definition...');
        await updateSpecDefinition(
          config.apiKey,
          finalSpecId,
          finalCollectionUid,
        );

        print('│');
        print('│  [2.3] Downloading spec definitions...');
        spec = await fetchSpecDefinitions(
          config.apiKey,
          finalSpecId,
          targetPath,
          specFile,
        );

        if (spec == null) {
          stderr.writeln('│');
          stderr.writeln('└─ ✗ Failed to download OpenAPI 3.0 spec\n');
          exit(1);
        }

        print('└─ ✓ OpenAPI 3.0 spec ready for code generation\n');
      }

      // Phase 3: Generate code
      print('┌─ Phase 3: Code Generation');
      print('│');
      print('│  Running build_runner...');
      print('│');

      final buildArgs = [
        'run',
        'build_runner',
        'build',
        if (deleteConflicting) '--delete-conflicting-outputs',
      ];

      final buildResult = await Process.start(
        'dart',
        buildArgs,
        workingDirectory: targetPath,
        mode: ProcessStartMode.inheritStdio,
      );

      final exitCode = await buildResult.exitCode;

      if (exitCode != 0) {
        stderr.writeln('│');
        stderr.writeln('└─ ✗ Code generation failed\n');
        exit(1);
      }

      print('│');
      print('└─ ✓ Code generated successfully\n');

      // Success summary
      print('═' * 70);
      print('  ✓ Complete! Generated code is in: $targetPath/$outputDir');
      print('═' * 70);
      print('');
    } catch (e) {
      stderr.writeln('\n✗ Error: $e\n');
      exit(1);
    }
  }
}
