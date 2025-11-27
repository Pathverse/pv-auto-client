import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'env_loader.dart';

/// Postman API base URL
const String baseUrl = 'https://api.getpostman.com/';

/// Configuration loaded from environment or .env file
class PostmanConfig {
  final String apiKey;
  final String? collectionUid;
  final String? specId;

  PostmanConfig({required this.apiKey, this.collectionUid, this.specId});
}

/// Load Postman configuration from environment or .env file in target project
Future<PostmanConfig> loadPostmanConfig(String targetProjectPath) async {
  final envVars = await loadEnvVariables(targetProjectPath);

  return PostmanConfig(
    apiKey: getRequiredEnv(envVars, 'XAPIKEY'),
    collectionUid: getOptionalEnv(envVars, 'XCOID'),
    specId: getOptionalEnv(envVars, 'XSPECID'),
  );
}

/// Send HTTP request to Postman API
Future<Map<String, dynamic>> sendRequest(
  String apiKey,
  String method,
  String endpoint, {
  Map<String, dynamic>? data,
  bool failGracefully = false,
}) async {
  final headers = {'X-Api-Key': apiKey, 'Content-Type': 'application/json'};

  final url = Uri.parse('$baseUrl$endpoint');
  http.Response response;

  switch (method.toUpperCase()) {
    case 'GET':
      response = await http.get(url, headers: headers);
      break;
    case 'POST':
      response = await http.post(
        url,
        headers: headers,
        body: data != null ? jsonEncode(data) : null,
      );
      break;
    case 'PUT':
      response = await http.put(
        url,
        headers: headers,
        body: data != null ? jsonEncode(data) : null,
      );
      break;
    case 'DELETE':
      response = await http.delete(url, headers: headers);
      break;
    default:
      throw Exception('Unsupported HTTP method: $method');
  }

  if (response.statusCode == 200 || response.statusCode == 202) {
    return jsonDecode(response.body) as Map<String, dynamic>;
  } else {
    final errorMsg =
        'Failed to send $method request. '
        'Status code: ${response.statusCode}, Error: ${response.body}';

    if (!failGracefully) {
      print(errorMsg);
      throw Exception(errorMsg);
    } else {
      print(errorMsg);
      return {'statusCode': response.statusCode, 'error': response.body};
    }
  }
}

/// Update Postman spec definitions (sync collection to spec)
Future<bool> updateSpecDefinition(
  String apiKey,
  String specId,
  String collectionUid,
) async {
  print('Updating definitions for spec $specId...');

  final endpoint =
      'specs/$specId/synchronizations?collectionUid=$collectionUid';

  try {
    final response = await sendRequest(apiKey, 'PUT', endpoint);

    if (response.containsKey('statusCode')) {
      final statusCode = response['statusCode'];
      if (statusCode == 400) {
        print('Spec definition is already up to date.');
        return true;
      }
      if (statusCode != 202) {
        print('Failed to update spec definition. Status code: $statusCode');
        return false;
      }
    }

    // Wait for task to complete
    await Future.delayed(const Duration(seconds: 5));
    print('Spec definition updated successfully.');
    return true;
  } catch (e) {
    print('Error updating spec definition: $e');
    return false;
  }
}

/// Fetch collection and convert to Swagger 2.0 using Postman's conversion service
Future<Map<String, dynamic>?> fetchCollectionAsSwagger(
  String apiKey,
  String collectionId,
  String targetProjectPath,
  String specFileName,
) async {
  print('Fetching collection $collectionId...');

  try {
    // Step 1: Get the collection from Postman API
    final collectionData = await sendRequest(
      apiKey,
      'GET',
      'collections/$collectionId',
      failGracefully: true,
    );

    if (collectionData.containsKey('error')) {
      return null;
    }

    // Step 2: Convert collection to Swagger using Postman's conversion service
    print('Converting collection to Swagger 2.0...');

    final conversionUrl = Uri.parse(
      'https://demo.postmansolutions.com/postman2swagger',
    );
    final conversionResponse = await http.post(
      conversionUrl,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(collectionData['collection']),
    );

    if (conversionResponse.statusCode != 200) {
      print('Error converting to Swagger: ${conversionResponse.statusCode}');
      return null;
    }

    final conversionResult =
        json.decode(conversionResponse.body) as Map<String, dynamic>;
    final swaggerData = conversionResult['swagger'] as Map<String, dynamic>;

    // Show any warnings or errors from conversion
    if (conversionResult.containsKey('warnings') &&
        conversionResult['warnings'] != null) {
      final warnings = conversionResult['warnings'] as List;
      if (warnings.isNotEmpty) {
        print('Conversion warnings: ${warnings.length} warning(s)');
      }
    }

    if (conversionResult.containsKey('errors') &&
        conversionResult['errors'] != null) {
      final errors = conversionResult['errors'] as List;
      if (errors.isNotEmpty) {
        print('Conversion errors: ${errors.length} error(s)');
      }
    }

    // Refactor the data to remove empty lists
    _refactorData(swaggerData);

    // Create specs directory if it doesn't exist
    final specsDir = Directory(path.join(targetProjectPath, 'specs'));
    if (!await specsDir.exists()) {
      await specsDir.create(recursive: true);
    }

    // Write to file
    final outputFile = File(path.join(specsDir.path, specFileName));
    final jsonString = const JsonEncoder.withIndent('  ').convert(swaggerData);
    await outputFile.writeAsString(jsonString, encoding: utf8);

    print('Swagger 2.0 spec saved to: ${outputFile.path}');
    return swaggerData;
  } catch (e) {
    print('Error fetching collection as Swagger: $e');
    return null;
  }
}

/// Fetch Postman spec definitions and save to target project
/// NOTE: This returns OpenAPI 3.0 format. Use fetchCollectionAsSwagger for Swagger 2.0
Future<Map<String, dynamic>?> fetchSpecDefinitions(
  String apiKey,
  String specId,
  String targetProjectPath,
  String specFileName,
) async {
  print('Fetching definitions for spec $specId...');

  final endpoint = 'specs/$specId/definitions';

  try {
    final data = await sendRequest(
      apiKey,
      'GET',
      endpoint,
      failGracefully: true,
    );

    if (data.containsKey('error')) {
      return null;
    }

    // Refactor the data to remove empty lists
    _refactorData(data);

    // Create specs directory if it doesn't exist
    final specsDir = Directory(path.join(targetProjectPath, 'specs'));
    if (!await specsDir.exists()) {
      await specsDir.create(recursive: true);
    }

    // Write to file
    final outputFile = File(path.join(specsDir.path, specFileName));
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    await outputFile.writeAsString(jsonString, encoding: utf8);

    print('Spec saved to: ${outputFile.path}');
    return data;
  } catch (e) {
    print('Error fetching spec definitions: $e');
    return null;
  }
}

/// Recursively remove empty lists from JSON data
void _refactorData(dynamic data) {
  if (data is Map<String, dynamic>) {
    final keysToRemove = <String>[];

    for (final entry in data.entries) {
      final value = entry.value;

      if (value is Map<String, dynamic>) {
        _refactorData(value);
      } else if (value is List) {
        // Remove empty items from list
        data[entry.key] = value.where((v) => v != null && v != '').toList();

        // Mark key for removal if list is now empty
        if ((data[entry.key] as List).isEmpty) {
          keysToRemove.add(entry.key);
        }
      }
    }

    // Remove keys with empty lists
    for (final key in keysToRemove) {
      data.remove(key);
    }
  } else if (data is List) {
    for (final item in data) {
      _refactorData(item);
    }
  }
}

/// Download collection and convert to Swagger 2.0
Future<bool> downloadCollectionAsSwagger({
  required String targetProjectPath,
  String? collectionUid,
  String specFileName = 'api_spec.json',
}) async {
  try {
    // Load configuration from target project
    final config = await loadPostmanConfig(targetProjectPath);

    // Use provided value or fall back to config from .env
    final finalCollectionUid = collectionUid ?? config.collectionUid;

    if (finalCollectionUid == null || finalCollectionUid.isEmpty) {
      throw Exception(
        'Collection UID not provided and XCOID not found in environment',
      );
    }

    // Fetch and convert collection to Swagger 2.0
    final spec = await fetchCollectionAsSwagger(
      config.apiKey,
      finalCollectionUid,
      targetProjectPath,
      specFileName,
    );

    if (spec == null) {
      print('Failed to fetch and convert collection to Swagger 2.0.');
      return false;
    }

    print('Successfully downloaded and converted collection to Swagger 2.0!');
    return true;
  } catch (e) {
    print('Error downloading collection as Swagger: $e');
    return false;
  }
}

/// Complete workflow: update spec and download definitions
/// NOTE: This uses OpenAPI 3.0 format. Use downloadCollectionAsSwagger for Swagger 2.0
Future<bool> updateAndDownloadSpec({
  required String targetProjectPath,
  String? specId,
  String? collectionUid,
  String specFileName = 'api_spec.json',
}) async {
  try {
    // Load configuration from target project
    final config = await loadPostmanConfig(targetProjectPath);

    // Use provided values or fall back to config from .env
    final finalSpecId = specId ?? config.specId;
    final finalCollectionUid = collectionUid ?? config.collectionUid;

    if (finalSpecId == null || finalSpecId.isEmpty) {
      throw Exception(
        'Spec ID not provided and XSPECID not found in environment',
      );
    }

    if (finalCollectionUid == null || finalCollectionUid.isEmpty) {
      throw Exception(
        'Collection UID not provided and XCOID not found in environment',
      );
    }

    // Update spec definition (sync from collection)
    final updateSuccess = await updateSpecDefinition(
      config.apiKey,
      finalSpecId,
      finalCollectionUid,
    );
    if (!updateSuccess) {
      print('Failed to update spec definition. Attempting download anyway...');
    }

    // Fetch and save spec definitions
    final spec = await fetchSpecDefinitions(
      config.apiKey,
      finalSpecId,
      targetProjectPath,
      specFileName,
    );

    if (spec == null) {
      print('Failed to fetch spec definitions.');
      return false;
    }

    print('Successfully updated and downloaded spec!');
    return true;
  } catch (e) {
    print('Error in update and download workflow: $e');
    return false;
  }
}
