# Health Passport

Health Passport is a privacy-first continuity layer for wearable health data.
The first version focuses on importing supported Fitbit/Google wearable data,
preserving it in a local-first vault, and writing clean supported records back
to Apple Health with user permission.

## Current Milestone

This repository is in Phase 1: foundation.

- Native SwiftUI app shell: `apps/ios/HealthPassport`
- Shared open-core sync models: `packages/core`
- Backend skeleton for Pro/backup/AI relay: `services/api`
- Planning and privacy docs: `docs`

## Verification

This workspace currently has Node available but not `npm`, and Swift through
Command Line Tools but not full Xcode. The first checks avoid dependency
installation:

```bash
node --test --experimental-transform-types packages/core/test/*.test.ts services/api/test/*.test.ts
swift build --package-path apps/ios/HealthPassport
```

Full iOS simulator and HealthKit entitlement validation require Xcode.
