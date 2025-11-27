# PV Auto Client

Automate Chopper API client generation from Postman collections.

## Quick Start

1. Create `.env` in your target project:
```env
XAPIKEY=your-postman-api-key
XCOID=your-collection-uid
```

2. Run:
```bash
pv_auto_client auto --target <path-to-project>
```

Done! Generated client will be in `<target>/lib/generated/`

## Commands

### Auto (Full Automation)
```bash
pv_auto_client auto --target <path-to-project>
```

### Setup Only
```bash
pv_auto_client setup --target <path-to-project>
```

### Download Only
```bash
pv_auto_client download-spec --output-path <path-to-project>
```

## Options

### Common Flags
- `--target` / `-t` - Target project path
- `--format` - Spec format: `swagger2` (default) or `openapi3`
- `--overwrite-dependencies` - Update dependencies in pubspec.yaml
- `--overwrite-build` - Overwrite existing build.yaml
- `--delete-conflicting` - Delete conflicting outputs (default: true)
- `--spec-file` / `-f` - Spec filename (default: `api_spec.json`)
- `--skip-setup` - Skip dependency and build.yaml setup

### OpenAPI 3.0 Mode
```bash
pv_auto_client auto --format openapi3 --spec-id <spec-id>
```

## Environment Variables

Set in your target project's `.env`:
- `XAPIKEY` - Postman API key (required)
- `XCOID` - Collection UID (required)
- `XSPECID` - Spec ID (for OpenAPI 3.0 mode)
