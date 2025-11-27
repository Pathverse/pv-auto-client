# Product Context

## Problem Statement
Developers working with APIs often maintain Postman collections for API documentation and testing. When building Dart/Flutter applications, they need to manually create HTTP clients to interact with these APIs. This creates:
- Duplication of effort (API defined in Postman, then manually coded in Dart)
- Synchronization issues when APIs change
- Potential for errors in manual implementation
- Time-consuming setup for each new API integration

## Solution
`pv_auto_client` bridges the gap between Postman collections and Dart code by:
1. Connecting to Postman API programmatically
2. Downloading collection specifications
3. Automatically generating type-safe Chopper clients
4. Keeping API clients in sync with Postman collections

## User Workflow
1. User has a Dart/Flutter project that needs API client
2. User configures Postman API credentials (env var or config)
3. User runs: `pv_auto_client --collection <id> --target <path-to-project>`
4. Tool authenticates to Postman
5. Tool downloads collection as OpenAPI spec to target project
6. Tool creates/updates `build.yaml` in target project
7. Tool executes `build_runner` in target project directory
8. Generated Chopper client appears in target project
9. User imports and uses generated client in their project

## Value Proposition
- **Time Savings**: Eliminates manual client coding
- **Accuracy**: Generated code matches API specification exactly
- **Maintainability**: Easy to regenerate when API changes
- **Type Safety**: Leverages Dart's strong typing with generated models
- **Best Practices**: Uses established libraries (Chopper, JSON serialization)

## User Experience Goals
- Simple command-line interface
- Clear progress feedback during operations
- Helpful error messages
- Minimal configuration required
- Fast execution
