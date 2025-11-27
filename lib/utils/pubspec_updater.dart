import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Add required dependencies to target project's pubspec.yaml
Future<bool> addRequiredDependencies({
  required String targetProjectPath,
  bool force = false,
}) async {
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
    final requiredDeps = {'chopper': '^8.0.3', 'json_annotation': '^4.9.0'};

    final requiredDevDeps = {
      'build_runner': '^2.4.9',
      'chopper_generator': '^8.0.3',
      'json_serializable': '^6.8.0',
      'swagger_dart_code_generator': '^4.1.0',
    };

    final missingDeps = <String, String>{};
    final missingDevDeps = <String, String>{};

    // Check what's missing
    for (final entry in requiredDeps.entries) {
      if (dependencies == null || !dependencies.containsKey(entry.key)) {
        missingDeps[entry.key] = entry.value;
      }
    }

    for (final entry in requiredDevDeps.entries) {
      if (devDependencies == null || !devDependencies.containsKey(entry.key)) {
        missingDevDeps[entry.key] = entry.value;
      }
    }

    if (missingDeps.isEmpty && missingDevDeps.isEmpty) {
      print('✓ All required dependencies already present');
      return true;
    }

    if (!force) {
      print('Missing dependencies found:');
      if (missingDeps.isNotEmpty) {
        print('  dependencies:');
        for (final entry in missingDeps.entries) {
          print('    ${entry.key}: ${entry.value}');
        }
      }
      if (missingDevDeps.isNotEmpty) {
        print('  dev_dependencies:');
        for (final entry in missingDevDeps.entries) {
          print('    ${entry.key}: ${entry.value}');
        }
      }
      print('\nRun with --force to automatically add these dependencies');
      return false;
    }

    // Add dependencies
    final lines = content.split('\n');
    final newLines = <String>[];
    var inDependencies = false;
    var inDevDependencies = false;
    var addedDeps = false;
    var addedDevDeps = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      newLines.add(line);

      // Track sections
      if (line.trim() == 'dependencies:') {
        inDependencies = true;
        inDevDependencies = false;
      } else if (line.trim() == 'dev_dependencies:') {
        inDependencies = false;
        inDevDependencies = true;
      } else if (line.isNotEmpty &&
          !line.startsWith(' ') &&
          !line.startsWith('\t')) {
        inDependencies = false;
        inDevDependencies = false;
      }

      // Add missing dependencies at end of dependencies section
      if (inDependencies && !addedDeps) {
        final nextLine = i + 1 < lines.length ? lines[i + 1] : '';
        if (nextLine.isEmpty ||
            (!nextLine.startsWith(' ') && !nextLine.startsWith('\t'))) {
          for (final entry in missingDeps.entries) {
            newLines.add('  ${entry.key}: ${entry.value}');
          }
          addedDeps = true;
        }
      }

      // Add missing dev_dependencies at end of dev_dependencies section
      if (inDevDependencies && !addedDevDeps) {
        final nextLine = i + 1 < lines.length ? lines[i + 1] : '';
        if (nextLine.isEmpty ||
            (!nextLine.startsWith(' ') && !nextLine.startsWith('\t'))) {
          for (final entry in missingDevDeps.entries) {
            newLines.add('  ${entry.key}: ${entry.value}');
          }
          addedDevDeps = true;
        }
      }
    }

    // If dependencies section doesn't exist, add it
    if (missingDeps.isNotEmpty && !addedDeps) {
      newLines.add('');
      newLines.add('dependencies:');
      for (final entry in missingDeps.entries) {
        newLines.add('  ${entry.key}: ${entry.value}');
      }
    }

    // If dev_dependencies section doesn't exist, add it
    if (missingDevDeps.isNotEmpty && !addedDevDeps) {
      newLines.add('');
      newLines.add('dev_dependencies:');
      for (final entry in missingDevDeps.entries) {
        newLines.add('  ${entry.key}: ${entry.value}');
      }
    }

    // Write back to file
    await pubspecFile.writeAsString(newLines.join('\n'));
    print('✓ Added missing dependencies to pubspec.yaml');
    print('  Run: dart pub get');

    return true;
  } catch (e) {
    print('Error updating pubspec.yaml: $e');
    return false;
  }
}
