import 'dart:io';
import 'package:path/path.dart' as path;

/// Load all environment variables from system and .env file
Future<Map<String, String>> loadEnvVariables(String targetProjectPath) async {
  final envVars = <String, String>{};

  // First load from system environment
  envVars.addAll(Platform.environment);

  // Then load from .env file in target project (overrides system env)
  final envFile = File(path.join(targetProjectPath, '.env'));
  if (await envFile.exists()) {
    final lines = await envFile.readAsLines();
    for (final line in lines) {
      final trimmed = line.trim();
      // Skip empty lines and comments
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }

      if (trimmed.contains('=')) {
        final parts = trimmed.split('=');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join('=').trim();
          if (key.isNotEmpty && value.isNotEmpty) {
            envVars[key] = value;
          }
        }
      }
    }
  }

  return envVars;
}

/// Get a required environment variable or throw an exception
String getRequiredEnv(Map<String, String> envVars, String key) {
  final value = envVars[key];
  if (value == null || value.isEmpty) {
    throw Exception('$key not found in environment or .env file');
  }
  return value;
}

/// Get an optional environment variable
String? getOptionalEnv(Map<String, String> envVars, String key) {
  final value = envVars[key];
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}
