import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Generate build.yaml configuration for swagger_dart_code_generator
String generateBuildYamlContent({
  String inputFolder = 'specs',
  String outputDirectory = 'lib/generated',
  bool useChopper = true,
  bool withConverter = true,
  bool separateModels = true,
}) {
  // Ensure folders have trailing slashes as required by swagger_dart_code_generator
  final inputFolderPath = inputFolder.endsWith('/')
      ? inputFolder
      : '$inputFolder/';
  final outputFolderPath = outputDirectory.endsWith('/')
      ? outputDirectory
      : '$outputDirectory/';

  return '''
# Build configuration for swagger_dart_code_generator
targets:
  \$default:
    sources:
      - lib/**
      - $inputFolderPath**
      - \$package\$
    builders:
      swagger_dart_code_generator:
        options:
          input_folder: "$inputFolderPath"
          output_folder: "$outputFolderPath"
          use_chopper: $useChopper
          with_converter: $withConverter
          separate_models: $separateModels
          build_only_models: false
          default_values_map: []
          response_override_value_map: []

      chopper_generator:
        options:
          header: "//Generated code"
          
      json_serializable:
        options:
          explicit_to_json: true
          any_map: false
          checked: true
''';
}

/// Create build.yaml file in target project
/// Creates new file if it doesn't exist
/// Only overwrites existing file if force=true
Future<bool> createBuildYaml({
  required String targetProjectPath,
  String inputFolder = 'specs',
  String outputDirectory = 'lib/generated',
  bool force = false,
}) async {
  final buildYamlPath = p.join(targetProjectPath, 'build.yaml');
  final buildYamlFile = File(buildYamlPath);

  // Check if file already exists
  if (await buildYamlFile.exists()) {
    if (!force) {
      print('✓ build.yaml already exists at: $buildYamlPath');
      print('  (Use --force to overwrite)');
      return true; // Not an error - file exists and is usable
    }
    print('⚠ Overwriting existing build.yaml at: $buildYamlPath');
  }

  // Generate content
  final content = generateBuildYamlContent(
    inputFolder: inputFolder,
    outputDirectory: outputDirectory,
  );

  // Write to file
  try {
    await buildYamlFile.writeAsString(content);
    print('✓ Created build.yaml at: $buildYamlPath');
    return true;
  } catch (e) {
    print('Error creating build.yaml: $e');
    return false;
  }
}

/// Validate that target project has required dependencies
Future<bool> validateTargetDependencies(String targetProjectPath) async {
  final pubspecPath = p.join(targetProjectPath, 'pubspec.yaml');
  final pubspecFile = File(pubspecPath);

  if (!await pubspecFile.exists()) {
    print('Error: pubspec.yaml not found in target project');
    return false;
  }

  try {
    final content = await pubspecFile.readAsString();
    final yaml = loadYaml(content);

    final dependencies = yaml['dependencies'] as YamlMap?;
    final devDependencies = yaml['dev_dependencies'] as YamlMap?;

    // Check for required dependencies
    final requiredDeps = ['chopper', 'json_annotation'];
    final requiredDevDeps = [
      'build_runner',
      'chopper_generator',
      'json_serializable',
      'swagger_dart_code_generator',
    ];

    final missingDeps = <String>[];
    final missingDevDeps = <String>[];

    for (final dep in requiredDeps) {
      if (dependencies == null || !dependencies.containsKey(dep)) {
        missingDeps.add(dep);
      }
    }

    for (final dep in requiredDevDeps) {
      if (devDependencies == null || !devDependencies.containsKey(dep)) {
        missingDevDeps.add(dep);
      }
    }

    if (missingDeps.isNotEmpty || missingDevDeps.isNotEmpty) {
      print('Warning: Missing dependencies in target project:');
      if (missingDeps.isNotEmpty) {
        print('  dependencies: ${missingDeps.join(", ")}');
      }
      if (missingDevDeps.isNotEmpty) {
        print('  dev_dependencies: ${missingDevDeps.join(", ")}');
      }
      print('\nAdd them to pubspec.yaml and run: dart pub get');
      return false;
    }

    print('✓ All required dependencies found');
    return true;
  } catch (e) {
    print('Error validating dependencies: $e');
    return false;
  }
}

/// Validate that target is a Dart project
Future<bool> validateTargetProject(String targetProjectPath) async {
  final targetDir = Directory(targetProjectPath);

  if (!await targetDir.exists()) {
    print('Error: Target directory does not exist: $targetProjectPath');
    return false;
  }

  final pubspecPath = p.join(targetProjectPath, 'pubspec.yaml');
  final pubspecFile = File(pubspecPath);

  if (!await pubspecFile.exists()) {
    print('Error: Not a Dart project (no pubspec.yaml found)');
    return false;
  }

  print('✓ Target is a valid Dart project');
  return true;
}
