# Project Brief: PV Auto Client

## Project Name
`pv_auto_client` - Postman to Chopper Client Generator

## Core Purpose
A command-line automation tool that:
1. Authenticates to Postman API
2. Downloads/updates Postman collections as OpenAPI specs
3. Creates build configuration in user's target project
4. Triggers code generation in the target project

This is a **service tool** - it generates code in OTHER projects, not in itself.

## Key Requirements

### Authentication
- Authenticate to Postman API automatically
- Handle API credentials securely

### Collection Management
- Update spec to collection in Postman
- Download collection from Postman to user-specified target directory
- Save as OpenAPI/Swagger specification

### Build Configuration
- Create or update `build.yaml` in target project
- Configure `swagger_dart_code_generator` settings
- Set correct input/output paths for target project

### Code Generation Orchestration
- Execute build_runner in the target project directory
- Generate Chopper client classes at target location
- Monitor generation progress and report status

## Technical Stack
- **Language**: Dart 3.10.1+
- **CLI Framework**: Native Dart console application
- **Dependencies**:
  - `path` - Cross-platform path manipulation for target directories
  - HTTP client for Postman API calls
  - Process execution for running build_runner in target projects
  
**Note**: This tool does NOT use Chopper or code generators for itself. Those are dependencies it helps configure in TARGET projects.

## Deliverables
1. Console tool with CLI interface
2. Postman API integration service
3. Automated collection download to target directory
4. Build configuration generator for target projects
5. Build runner orchestration

## Success Criteria
- Tool authenticates to Postman successfully
- Collections download to user-specified locations
- `build.yaml` created/updated correctly in target projects
- Build runner executes successfully in target projects
- Generated code appears in target project's specified output directory
