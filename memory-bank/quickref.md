# Quick Reference

## Project Overview
**PV Auto Client** - A SERVICE TOOL that automates Chopper client generation in OTHER Dart projects from Postman collections.

**CRITICAL**: This tool creates files in TARGET projects, not in itself.

## What This Tool Does
1. Downloads Postman collections as OpenAPI specs
2. Saves specs to TARGET project
3. Creates `build.yaml` in TARGET project
4. Runs `build_runner` in TARGET project
5. Generated code appears in TARGET project

## Usage
```bash
# Set API key
$env:POSTMAN_API_KEY = "your-key"

# Run tool
pv_auto_client \
  --collection <postman-collection-id> \
  --target <path-to-dart-project> \
  --output lib/generated \
  --spec-dir specs
```

## This Project Structure
- `bin/` - CLI entry point
- `lib/` - Service library code
  - `postman/` - Postman API client
  - `project/` - Target project operations
  - `generator/` - Build config generation
- `memory-bank/` - Project documentation

## Key Dependencies (This Tool)
- `http` or `dio` - Postman API communication
- `args` - CLI argument parsing
- `yaml` - Build.yaml generation
- `path` - Cross-platform paths

## Dependencies for TARGET Projects
Target projects need:
- `chopper ^8.0.3`
- `build_runner ^2.4.9`
- `swagger_dart_code_generator ^4.1.0`
- Plus generators

## Implementation Flow
```
CLI Parse Args → Validate Target → Postman API → Download Spec →
Write to Target/specs/ → Generate Target/build.yaml →
Execute in Target: dart run build_runner build →
Target/lib/generated/ contains client
```

## Memory Bank Files
1. `projectbrief.md` - Service tool requirements
2. `productContext.md` - Problem and workflow
3. `systemPatterns.md` - Service architecture
4. `techContext.md` - Tech stack
5. `activeContext.md` - Current state
6. `progress.md` - Status tracking
7. `quickref.md` - This file
