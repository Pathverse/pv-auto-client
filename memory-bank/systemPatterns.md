# System Patterns

## Architecture Overview
This is a **service automation tool** that operates on OTHER projects:

```
[CLI Entry] → [Load Config from Target] → [Download Collection] → 
[Convert to Swagger via Postman Service] → [Write Spec to Target] → 
[Generate build.yaml in Target] → [Run build_runner in Target] → [Report Success]
```

**Key Insight**: Uses Postman's conversion service to transform collections to Swagger 2.0

## Key Components

### 1. CLI Entry Point
- **Location**: `bin/pv_auto_client.dart`
- **Responsibility**: Parse arguments (collection ID, target project path), coordinate workflow
- **Pattern**: Command pattern for orchestration

### 2. Postman API Client
- **Responsibility**: Communicate with Postman API
- **Key Operations**:
  - Authentication with API key
  - Collection retrieval
  - Collection update detection
- **Output**: OpenAPI/Swagger specification data

### 3. Target Project Manager
- **Responsibility**: Interact with user's target project
- **Key Operations**:
  - Validate target directory exists and is a Dart project
  - Write OpenAPI spec to target project (e.g., `target/specs/api.yaml`)
  - Create/update `build.yaml` with correct paths
  - Ensure target has required dependencies in pubspec.yaml

### 4. Build Orchestrator
- **Responsibility**: Execute code generation in target project
- **Key Operations**:
  - Run `dart run build_runner build` in target directory
  - Capture and display output
  - Handle errors from build process
  - Verify generation completed successfully

## Design Decisions

### Why This Approach?
- **Automation**: Eliminates manual setup steps for users
- **Correctness**: Generates proper build.yaml configuration
- **Integration**: Works with user's existing projects
- **Transparency**: User can see and version control the spec and config

### Build Configuration Strategy
- Generate `build.yaml` programmatically based on project structure
- Set input_folder to where we save the spec
- Set output_directory based on user preferences or defaults
- Include all necessary generator options

### Process Execution
- Run build_runner as separate process in target directory
- Stream output to user for transparency
- Handle process exit codes properly
- Clean up on failure

## Data Flow

```
User Command
    ↓
Load .env from Target Project (XAPIKEY, XCOID)
    ↓
Postman API → Download Collection (native format)
    ↓
Postman Conversion Service → Convert to Swagger 2.0
    ↓
Target Project/specs/ ← Write Swagger 2.0 Spec
    ↓
Target Project/build.yaml ← Generate Config (input_folder, output_folder, sources)
    ↓
Target Project/pubspec.yaml ← Add Dependencies (if needed)
    ↓
Execute: dart pub get (in target dir)
    ↓
Execute: dart run build_runner build --delete-conflicting-outputs (in target dir)
    ↓
Target Project/lib/generated/ ← Generated Chopper Client
```

**Critical**: This tool creates files in the TARGET project, not in itself.
**Conversion Service**: `https://demo.postmansolutions.com/postman2swagger`

## Critical Paths

### Complete Workflow
1. Parse CLI arguments (--collection, --target, --output-dir)
2. Validate target directory is a Dart project
3. Authenticate to Postman API
4. Download collection as OpenAPI spec
5. Write spec to target project's specs directory
6. Generate/update build.yaml in target project
7. Check target project has required dependencies
8. Execute build_runner in target directory
9. Monitor build process
10. Report success and location of generated files

### Target Project Validation
1. Check target path exists
2. Check for pubspec.yaml in target
3. Verify it's a Dart project
4. Warn if required dependencies missing

## Error Handling Strategy
- Validate inputs early
- Provide specific error messages
- Graceful degradation where possible
- Log errors for debugging
