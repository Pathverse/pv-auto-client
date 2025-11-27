import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../utils/postman_downloader.dart';

/// Download Postman spec command
class DownloadSpecCommand extends Command<void> {
  @override
  String get name => 'download-spec';

  @override
  String get description =>
      'Download Postman collection spec (Swagger 2.0 by default)';

  DownloadSpecCommand() {
    argParser
      ..addOption(
        'format',
        help: 'Spec format: swagger2 or openapi3',
        allowed: ['swagger2', 'openapi3'],
        defaultsTo: 'swagger2',
      )
      ..addFlag(
        'no-spec-update',
        abbr: 'n',
        negatable: false,
        help: 'Skip updating spec before downloading (OpenAPI 3.0 mode only)',
      )
      ..addOption(
        'output-path',
        abbr: 'o',
        help: 'Output path for the spec file (default: current directory)',
        defaultsTo: Directory.current.path,
      )
      ..addOption(
        'spec-file',
        abbr: 'f',
        help: 'Output filename',
        defaultsTo: 'api_spec.json',
      )
      ..addOption(
        'spec-id',
        help:
            'Postman spec ID (required for openapi3 format, or set XSPECID in .env)',
      )
      ..addOption(
        'collection-uid',
        help: 'Postman collection UID (or set XCOID in .env)',
      );
  }

  @override
  Future<void> run() async {
    final results = argResults!;
    final format = results['format'] as String;
    final noUpdate = results['no-spec-update'] as bool;
    final outputPath = results['output-path'] as String;
    final specFile = results['spec-file'] as String;
    final specId = results['spec-id'] as String?;
    final collectionUid = results['collection-uid'] as String?;

    try {
      // Load configuration
      print('Loading configuration from $outputPath...');
      final config = await loadPostmanConfig(outputPath);

      // Determine final values
      final finalCollectionUid = collectionUid ?? config.collectionUid;

      if (format == 'swagger2') {
        // Swagger 2.0 mode - direct from collection
        print('Format: Swagger 2.0 (direct from collection)');

        if (finalCollectionUid == null || finalCollectionUid.isEmpty) {
          stderr.writeln(
            'Error: Collection UID not provided and XCOID not found in environment',
          );
          exit(1);
        }

        print('Downloading collection as Swagger 2.0...');
        final spec = await fetchCollectionAsSwagger(
          config.apiKey,
          finalCollectionUid,
          outputPath,
          specFile,
        );

        if (spec == null) {
          stderr.writeln('Failed to download collection as Swagger 2.0');
          exit(1);
        }

        final fullPath = p.join(outputPath, 'specs', specFile);
        print('✓ Success! Swagger 2.0 spec saved to: $fullPath');
      } else {
        // OpenAPI 3.0 mode - via spec definitions
        print('Format: OpenAPI 3.0 (via spec definitions)');

        final finalSpecId = specId ?? config.specId;

        if (finalSpecId == null || finalSpecId.isEmpty) {
          stderr.writeln(
            'Error: Spec ID not provided and XSPECID not found in environment',
          );
          exit(1);
        }

        // Update spec if not skipped
        if (!noUpdate) {
          if (finalCollectionUid == null || finalCollectionUid.isEmpty) {
            stderr.writeln(
              'Warning: Collection UID not provided and XCOID not found in environment',
            );
            stderr.writeln('Skipping spec update...');
          } else {
            print('Updating spec definition...');
            await updateSpecDefinition(
              config.apiKey,
              finalSpecId,
              finalCollectionUid,
            );
          }
        } else {
          print('Skipping spec update (--no-spec-update flag set)');
        }

        // Download spec
        print('Downloading spec definitions...');
        final spec = await fetchSpecDefinitions(
          config.apiKey,
          finalSpecId,
          outputPath,
          specFile,
        );

        if (spec == null) {
          stderr.writeln('Failed to download spec definitions');
          exit(1);
        }

        final fullPath = p.join(outputPath, 'specs', specFile);
        print('✓ Success! OpenAPI 3.0 spec saved to: $fullPath');
      }
    } catch (e) {
      stderr.writeln('Error: $e');
      exit(1);
    }
  }
}
