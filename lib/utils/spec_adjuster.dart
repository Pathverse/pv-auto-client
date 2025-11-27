import 'dart:io';
import 'dart:convert';

/// Adjust OpenAPI 3.0 specs to be compatible with swagger_dart_code_generator
///
/// This fixes common issues:
/// - Converts security definitions that use empty arrays
/// - Removes problematic OpenAPI 3.0 features
/// - Ensures compatibility with Swagger 2.0 parser
Future<bool> adjustSpecForCompatibility({
  required String specFilePath,
  bool backup = true,
}) async {
  final specFile = File(specFilePath);

  if (!await specFile.exists()) {
    print('Error: Spec file not found at $specFilePath');
    return false;
  }

  try {
    print('Reading spec file...');
    final content = await specFile.readAsString();
    final spec = jsonDecode(content) as Map<String, dynamic>;

    bool modified = false;

    // Create backup if requested
    if (backup) {
      final backupPath = '$specFilePath.backup';
      await File(backupPath).writeAsString(content);
      print('✓ Backup created at: $backupPath');
    }

    // Fix 1: Move path-level parameters to operation level
    if (spec.containsKey('paths')) {
      modified =
          _movePathParametersToOperations(
            spec['paths'] as Map<String, dynamic>,
          ) ||
          modified;
    }

    // Fix 2: Remove security arrays with empty scopes that cause parsing issues
    if (spec.containsKey('paths')) {
      modified =
          _fixSecurityDefinitions(spec['paths'] as Map<String, dynamic>) ||
          modified;
    }

    // Fix 3: Ensure all operations have operationId
    if (spec.containsKey('paths')) {
      modified =
          _ensureOperationIds(spec['paths'] as Map<String, dynamic>) ||
          modified;
    }

    // Fix 4: Convert OpenAPI 3.0 servers to Swagger 2.0 host/basePath if needed
    if (spec.containsKey('openapi') && spec.containsKey('servers')) {
      modified = _convertServersToHost(spec) || modified;
    }

    if (modified) {
      // Write adjusted spec back to file
      final encoder = JsonEncoder.withIndent('  ');
      final adjustedContent = encoder.convert(spec);
      await specFile.writeAsString(adjustedContent);
      print('✓ Spec adjusted and saved');
      return true;
    } else {
      print('✓ No adjustments needed');
      return true;
    }
  } catch (e) {
    print('Error adjusting spec: $e');
    return false;
  }
}

/// Move path-level parameters to each operation and convert OpenAPI 3.0 to Swagger 2.0 format
/// OpenAPI 3.0 allows parameters at path level, but Swagger 2.0 parser expects them at operation level
bool _movePathParametersToOperations(Map<String, dynamic> paths) {
  bool modified = false;

  paths.forEach((path, pathItem) {
    if (pathItem is! Map<String, dynamic>) return;

    // Check if path has parameters
    if (pathItem.containsKey('parameters')) {
      final pathParameters = pathItem['parameters'];

      if (pathParameters is List) {
        // Convert parameters to Swagger 2.0 format
        final convertedParams = _convertParametersToSwagger2(pathParameters);

        // Move parameters to each operation
        pathItem.forEach((method, operation) {
          if (operation is! Map<String, dynamic>) return;

          // Skip non-operation fields
          if (method == 'parameters' ||
              method == 'servers' ||
              method == 'summary' ||
              method == 'description')
            return;

          // Add path parameters to operation parameters
          if (!operation.containsKey('parameters')) {
            operation['parameters'] = [];
          }

          final operationParameters = operation['parameters'] as List;

          // Add converted path parameters
          for (var pathParam in convertedParams) {
            operationParameters.add(pathParam);
          }

          modified = true;
        });

        // Remove path-level parameters
        pathItem.remove('parameters');
        print('  Moved path-level parameters to operations in $path');
      }
    }

    // Also convert parameters that are already at operation level
    pathItem.forEach((method, operation) {
      if (operation is! Map<String, dynamic>) return;
      if (method == 'parameters' || method == 'servers') return;

      if (operation.containsKey('parameters')) {
        final params = operation['parameters'];
        if (params is List && params.isNotEmpty) {
          operation['parameters'] = _convertParametersToSwagger2(params);
          modified = true;
        }
      }
    });
  });

  return modified;
}

/// Convert OpenAPI 3.0 parameter format to Swagger 2.0 format
List<Map<String, dynamic>> _convertParametersToSwagger2(
  List<dynamic> parameters,
) {
  final converted = <Map<String, dynamic>>[];

  for (var param in parameters) {
    if (param is! Map<String, dynamic>) continue;

    final convertedParam = <String, dynamic>{};

    // Copy basic fields
    if (param.containsKey('name')) convertedParam['name'] = param['name'];
    if (param.containsKey('in')) convertedParam['in'] = param['in'];
    if (param.containsKey('description'))
      convertedParam['description'] = param['description'];
    if (param.containsKey('required'))
      convertedParam['required'] = param['required'];

    // Handle schema - OpenAPI 3.0 has nested schema object, Swagger 2.0 has flat structure
    if (param.containsKey('schema')) {
      final schema = param['schema'];
      if (schema is Map<String, dynamic>) {
        // Flatten schema properties to parameter level
        if (schema.containsKey('type')) convertedParam['type'] = schema['type'];
        if (schema.containsKey('format'))
          convertedParam['format'] = schema['format'];
        if (schema.containsKey('enum')) convertedParam['enum'] = schema['enum'];
        if (schema.containsKey('default'))
          convertedParam['default'] = schema['default'];
        if (schema.containsKey('items'))
          convertedParam['items'] = schema['items'];
      } else if (schema is List && schema.isEmpty) {
        // Empty array schema - default to string type
        convertedParam['type'] = 'string';
      }
    }

    // If no type was set, default to string
    if (!convertedParam.containsKey('type')) {
      convertedParam['type'] = 'string';
    }

    converted.add(convertedParam);
  }

  return converted;
}

/// Fix security definitions that use empty arrays
bool _fixSecurityDefinitions(Map<String, dynamic> paths) {
  bool modified = false;

  paths.forEach((path, pathItem) {
    if (pathItem is! Map<String, dynamic>) return;

    pathItem.forEach((method, operation) {
      if (operation is! Map<String, dynamic>) return;

      // Check if operation has security field
      if (operation.containsKey('security')) {
        final security = operation['security'];

        // If security is a list with maps containing empty arrays, remove it
        if (security is List) {
          bool hasEmptyArrays = false;
          for (var item in security) {
            if (item is Map<String, dynamic>) {
              for (var value in item.values) {
                if (value is List && value.isEmpty) {
                  hasEmptyArrays = true;
                  break;
                }
              }
            }
          }

          if (hasEmptyArrays) {
            // Remove the security field entirely or convert to simpler format
            operation.remove('security');
            modified = true;
            print('  Fixed security definition in $method $path');
          }
        }
      }
    });
  });

  return modified;
}

/// Ensure all operations have operationId
bool _ensureOperationIds(Map<String, dynamic> paths) {
  bool modified = false;
  int counter = 0;

  paths.forEach((path, pathItem) {
    if (pathItem is! Map<String, dynamic>) return;

    pathItem.forEach((method, operation) {
      if (operation is! Map<String, dynamic>) return;

      // Skip parameters and other non-operation fields
      if (method == 'parameters' || method == 'servers') return;

      if (!operation.containsKey('operationId') ||
          operation['operationId'] == null ||
          (operation['operationId'] as String).isEmpty) {
        // Generate operationId from path and method
        final cleanPath = path
            .replaceAll('/', '_')
            .replaceAll('{', '')
            .replaceAll('}', '')
            .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
        operation['operationId'] = '${method}_${cleanPath}_$counter';
        counter++;
        modified = true;
        print('  Added operationId for $method $path');
      }
    });
  });

  return modified;
}

/// Convert OpenAPI 3.0 servers to Swagger 2.0 host/basePath
bool _convertServersToHost(Map<String, dynamic> spec) {
  if (!spec.containsKey('servers')) return false;

  final servers = spec['servers'];
  if (servers is! List || servers.isEmpty) return false;

  final firstServer = servers[0];
  if (firstServer is! Map<String, dynamic>) return false;

  final url = firstServer['url'] as String?;
  if (url == null || url.isEmpty) return false;

  // Skip if it's a variable (like {{baseurl}})
  if (url.contains('{{')) {
    print('  Keeping variable server URL: $url');
    return false;
  }

  try {
    final uri = Uri.parse(url);
    if (uri.host.isNotEmpty) {
      spec['host'] = '${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
      spec['basePath'] = uri.path.isEmpty ? '/' : uri.path;
      spec['schemes'] = [uri.scheme];
      spec.remove('servers');
      print('  Converted servers to host/basePath');
      return true;
    }
  } catch (e) {
    print('  Could not parse server URL: $url');
  }

  return false;
}

/// Validate spec file can be parsed
Future<bool> validateSpec(String specFilePath) async {
  final specFile = File(specFilePath);

  if (!await specFile.exists()) {
    print('Error: Spec file not found at $specFilePath');
    return false;
  }

  try {
    final content = await specFile.readAsString();
    final spec = jsonDecode(content);

    if (spec is! Map<String, dynamic>) {
      print('Error: Spec is not a valid JSON object');
      return false;
    }

    // Check for required fields
    if (!spec.containsKey('paths')) {
      print('Error: Spec missing required "paths" field');
      return false;
    }

    print('✓ Spec file is valid JSON with paths');
    return true;
  } catch (e) {
    print('Error validating spec: $e');
    return false;
  }
}
