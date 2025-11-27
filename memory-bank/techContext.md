# Technical Context

## Technology Stack

### Core Language
- **Dart**: 3.10.1+
- Modern Dart features available
- Null safety enabled

### Dependencies

#### Runtime Dependencies
- `path: ^1.9.0` - Cross-platform file path manipulation for target directories
- HTTP client (e.g., `http` or `dio`) - For Postman API communication
- `args` - CLI argument parsing
- `yaml` - For reading/writing build.yaml files

#### Development Dependencies
- `lints: ^6.0.0` - Dart linting rules
- `test: ^1.25.6` - Testing framework

**IMPORTANT**: Chopper, build_runner, and code generators are NOT dependencies of this tool. They are dependencies that the tool helps configure in TARGET projects.

## Development Environment

### Required Tools
- Dart SDK 3.10.1 or higher
- Build runner for code generation
- Text editor / IDE with Dart support

### Project Structure
```
pv-auto-client/
├── bin/                    # CLI entry point
├── lib/                    # Service library code
│   ├── postman/            # Postman API client
│   ├── project/            # Target project operations
│   └── generator/          # Build config generation
├── test/                   # Unit tests
├── memory-bank/            # Project documentation
├── pubspec.yaml            # Tool dependencies
└── analysis_options.yaml   # Linter configuration
```

**Note**: No build.yaml needed in this project. This tool CREATES build.yaml in target projects.

## Target Project Requirements

### What Target Projects Need
For this tool to work, target projects must have:

```yaml
# target-project/pubspec.yaml
dependencies:
  chopper: ^8.0.3
  json_annotation: ^4.9.0

dev_dependencies:
  build_runner: ^2.4.9
  chopper_generator: ^8.0.3
  json_serializable: ^6.8.0
  swagger_dart_code_generator: ^4.1.0
```

### Build Configuration Generation
This tool will CREATE `build.yaml` in target projects with:
- Input folder pointing to where spec was saved
- Output directory for generated code
- Generator options for Chopper and JSON serialization

### Process Execution
This tool runs in target directory:
```bash
cd /path/to/target/project
dart run build_runner build --delete-conflicting-outputs
```

## Postman API Integration

### API Requirements
- Postman API key for authentication
- API endpoint: `https://api.getpostman.com`
- Key endpoints:
  - `/collections` - List collections
  - `/collections/{id}` - Get specific collection
  - Authentication via `X-Api-Key` header

### Collection Format
- Postman collections can be exported as OpenAPI/Swagger
- Need to convert Postman format to OpenAPI format if necessary
- OpenAPI 3.0+ preferred for best compatibility

## Technical Constraints

### File System
- Must handle cross-platform paths (use `path` package)
- Need write permissions in TARGET project directory
- Must validate target directory exists and is writable
- Respect existing files (warn before overwriting)

### Network
- Requires internet connection for Postman API
- Handle network errors gracefully
- Consider rate limiting on Postman API

### Process Execution
- Must execute build_runner in target project's context
- Handle different Dart SDK versions in target
- Stream output to user in real-time
- Handle build failures gracefully
- May take time - provide progress feedback

### Target Project Validation
- Check pubspec.yaml exists
- Verify required dependencies present
- Warn if dependencies missing

## Security Considerations
- API keys should not be hardcoded
- Consider environment variables or config files
- Never commit credentials to version control
- Validate downloaded content before processing
